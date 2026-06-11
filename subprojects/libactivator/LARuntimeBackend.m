//
//  LARuntimeBackend.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LARuntimeBackend.h"

#import "LAPersistence.h"

#import <HBLog.h>
#import <dispatch/dispatch.h>

static const void *LARuntimeBackendStateQueueKey = &LARuntimeBackendStateQueueKey;

static NSString *const LAActivatorDefaultProfileName = @"Default";
static NSString *const LAActivatorSchemaVersionKey = @"SchemaVersion";
static NSString *const LAActivatorCurrentProfileNameKey = @"CurrentProfileName";
static NSString *const LAActivatorProfilesKey = @"Profiles";
static NSString *const LAActivatorAssignmentsKey = @"Assignments";
static NSString *const LAActivatorBlacklistedDisplayIdentifiersKey = @"BlacklistedDisplayIdentifiers";
static NSString *const LAActivatorSeenListenerNamesKey = @"SeenListenerNames";
static NSString *const LAActivatorLegacyPreferencesKey = @"LegacyPreferences";

@interface LARuntimeBackend ()
@property(nonatomic, strong) NSMutableDictionary *eventDataSources;
@property(nonatomic, strong) NSMutableDictionary *listeners;
@property(nonatomic, strong) NSMutableDictionary *profiles;
@property(nonatomic, strong) NSMutableSet *blacklistedDisplayIdentifiers;
@property(nonatomic, strong) NSMutableSet *seenListenerNames;
@property(nonatomic, strong) NSMutableDictionary *legacyPreferences;
@property(nonatomic, copy) NSArray *cachedListenerNames;
@property(nonatomic, strong) dispatch_queue_t stateQueue;
@property(nonatomic, strong) LAPersistence *persistence;
@property(nonatomic, assign) BOOL persistentStateDirty;
@property(nonatomic, assign) BOOL persistentSaveScheduled;
@property(nonatomic, copy) NSString *storedCurrentProfileName;
@property(nonatomic, assign) CFRunLoopObserverRef persistentSaveObserver;
@end

@implementation LARuntimeBackend

#pragma mark - Lifecycle

- (instancetype)initWithPersistence:(LAPersistence *)persistence {
    self = [super init];
    if (self) {
        _persistence = persistence;
        _eventDataSources = [[NSMutableDictionary alloc] init];
        _listeners = [[NSMutableDictionary alloc] init];
        _profiles = [[NSMutableDictionary alloc] init];
        _blacklistedDisplayIdentifiers = [[NSMutableSet alloc] init];
        _seenListenerNames = [[NSMutableSet alloc] init];
        _legacyPreferences = [[NSMutableDictionary alloc] init];
        _stateQueue = dispatch_queue_create("libactivator.state", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        dispatch_queue_set_specific(_stateQueue, LARuntimeBackendStateQueueKey, (void *)LARuntimeBackendStateQueueKey,
                                    NULL);
        [self resetRuntimeState];
        [self loadPersistentState];
    }
    return self;
}

- (void)dealloc {
    if (self.persistentSaveObserver) {
        CFRunLoopObserverInvalidate(self.persistentSaveObserver);
        CFRelease(self.persistentSaveObserver);
        self.persistentSaveObserver = NULL;
    }
}

- (void)resetRuntimeState {
    self.storedCurrentProfileName = LAActivatorDefaultProfileName;
    self.profiles[LAActivatorDefaultProfileName] =
        [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
    [self.legacyPreferences removeAllObjects];
}

#pragma mark - Utilities

+ (NSArray *)normalizedStringArray:(NSArray *)array {
    if (![array isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![strings containsObject:value]) {
            [strings addObject:value];
        }
    }
    return [[strings sortedArrayUsingSelector:@selector(compare:)] copy];
}

- (NSMutableDictionary *)assignmentsForCurrentProfile {
    NSMutableDictionary *profile = self.profiles[self.storedCurrentProfileName];
    if (!profile) {
        profile = [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
        self.profiles[self.storedCurrentProfileName] = profile;
    }

    NSMutableDictionary *assignments = profile[LAActivatorAssignmentsKey];
    if (![assignments isKindOfClass:NSMutableDictionary.class]) {
        assignments = [[NSMutableDictionary alloc] init];
        profile[LAActivatorAssignmentsKey] = assignments;
    }
    return assignments;
}

- (void)savePersistentState {
    if (!self.persistence) {
        return;
    }

    void (^markDirty)(void) = ^{
        self.persistentStateDirty = YES;
        if (self.persistentSaveScheduled) {
            return;
        }
        self.persistentSaveScheduled = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self installPersistentSaveObserverIfNeeded];
        });
    };

    if ([self isRunningOnStateQueue]) {
        markDirty();
    } else {
        dispatch_sync(self.stateQueue, markDirty);
    }
}

- (BOOL)flushPendingPersistentState {
    __block NSDictionary *dictionary = nil;

    void (^copyPendingDictionary)(void) = ^{
        if (!self.persistence || !self.persistentStateDirty) {
            self.persistentSaveScheduled = NO;
            return;
        }
        dictionary = [self persistentStateDictionary];
        self.persistentStateDirty = NO;
        self.persistentSaveScheduled = NO;
    };

    if ([self isRunningOnStateQueue]) {
        copyPendingDictionary();
    } else {
        dispatch_sync(self.stateQueue, copyPendingDictionary);
    }

    if (!dictionary) {
        return YES;
    }

    BOOL saved = [self.persistence saveDictionary:dictionary];
    if (!saved) {
        HBLogError(@"Failed to save persistent state");
    }
    return saved;
}

- (NSDictionary *)persistentStateDictionary {
    NSMutableDictionary *serializedProfiles = [[NSMutableDictionary alloc] init];
    for (NSString *profileName in self.profiles) {
        NSDictionary *profile = self.profiles[profileName];
        NSDictionary *assignments = profile[LAActivatorAssignmentsKey] ?: @{};
        serializedProfiles[profileName] = @{LAActivatorAssignmentsKey : assignments};
    }

    NSDictionary *dictionary = @{
        LAActivatorSchemaVersionKey : @1,
        LAActivatorCurrentProfileNameKey : self.storedCurrentProfileName ?: LAActivatorDefaultProfileName,
        LAActivatorProfilesKey : serializedProfiles,
        LAActivatorBlacklistedDisplayIdentifiersKey :
            [self.blacklistedDisplayIdentifiers.allObjects sortedArrayUsingSelector:@selector(compare:)],
        LAActivatorSeenListenerNamesKey :
            [self.seenListenerNames.allObjects sortedArrayUsingSelector:@selector(compare:)],
        LAActivatorLegacyPreferencesKey : self.legacyPreferences ?: @{},
    };
    return dictionary;
}

- (BOOL)isRunningOnStateQueue {
    return dispatch_get_specific(LARuntimeBackendStateQueueKey) == LARuntimeBackendStateQueueKey;
}

- (void)installPersistentSaveObserverIfNeeded {
    __block BOOL shouldInstall = NO;
    dispatch_sync(self.stateQueue, ^{
        shouldInstall =
            self.persistentStateDirty && self.persistentSaveScheduled && self.persistentSaveObserver == NULL;
    });
    if (!shouldInstall) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    CFRunLoopObserverRef observer =
        CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, false, 0,
                                           ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                                               __strong typeof(weakSelf) strongSelf = weakSelf;
                                               if (!strongSelf) {
                                                   return;
                                               }
                                               if (strongSelf.persistentSaveObserver) {
                                                   CFRunLoopObserverInvalidate(strongSelf.persistentSaveObserver);
                                                   CFRelease(strongSelf.persistentSaveObserver);
                                                   strongSelf.persistentSaveObserver = NULL;
                                               }
                                               [strongSelf flushPendingPersistentState];
                                           });
    if (!observer) {
        [self flushPendingPersistentState];
        return;
    }

    self.persistentSaveObserver = observer;
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
}

#pragma mark - Persistence

- (void)loadPersistentState {
    NSDictionary *dictionary = [self.persistence loadDictionary];
    if (!dictionary) {
        return;
    }

    NSNumber *schemaVersion = dictionary[LAActivatorSchemaVersionKey];
    NSDictionary *profiles = dictionary[LAActivatorProfilesKey];
    NSString *currentProfileName = dictionary[LAActivatorCurrentProfileNameKey];
    if (![schemaVersion isKindOfClass:NSNumber.class] || schemaVersion.integerValue != 1 ||
        ![profiles isKindOfClass:NSDictionary.class]) {
        [self resetRuntimeState];
        return;
    }

    NSMutableDictionary *loadedProfiles = [[NSMutableDictionary alloc] init];
    for (id profileName in profiles) {
        if (![profileName isKindOfClass:NSString.class] || [profileName length] == 0) {
            continue;
        }
        NSDictionary *profile = profiles[profileName];
        NSDictionary *assignments =
            [profile isKindOfClass:NSDictionary.class] ? profile[LAActivatorAssignmentsKey] : nil;
        NSMutableDictionary *loadedAssignments = [[NSMutableDictionary alloc] init];
        if ([assignments isKindOfClass:NSDictionary.class]) {
            for (id eventName in assignments) {
                if (![eventName isKindOfClass:NSString.class] || [eventName length] == 0) {
                    continue;
                }
                NSDictionary *modes = assignments[eventName];
                if (![modes isKindOfClass:NSDictionary.class]) {
                    continue;
                }

                NSMutableDictionary *loadedModes = [[NSMutableDictionary alloc] init];
                for (id mode in modes) {
                    if (![mode isKindOfClass:NSString.class]) {
                        continue;
                    }
                    NSArray *listenerNames = [LARuntimeBackend normalizedStringArray:modes[mode]];
                    if (listenerNames.count > 0) {
                        loadedModes[mode] = listenerNames;
                    }
                }
                if (loadedModes.count > 0) {
                    loadedAssignments[eventName] = loadedModes;
                }
            }
        }
        loadedProfiles[profileName] = [@{LAActivatorAssignmentsKey : loadedAssignments} mutableCopy];
    }

    if (loadedProfiles.count == 0) {
        loadedProfiles[LAActivatorDefaultProfileName] =
            [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
    }
    if (![currentProfileName isKindOfClass:NSString.class] || currentProfileName.length == 0 ||
        !loadedProfiles[currentProfileName]) {
        currentProfileName = LAActivatorDefaultProfileName;
    }
    if (!loadedProfiles[currentProfileName]) {
        loadedProfiles[currentProfileName] =
            [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
    }

    NSArray *blacklistedDisplayIdentifiers =
        [LARuntimeBackend normalizedStringArray:dictionary[LAActivatorBlacklistedDisplayIdentifiersKey]];
    NSArray *seenListenerNames = [LARuntimeBackend normalizedStringArray:dictionary[LAActivatorSeenListenerNamesKey]];
    NSDictionary *legacyPreferences = dictionary[LAActivatorLegacyPreferencesKey];
    self.profiles = loadedProfiles;
    self.blacklistedDisplayIdentifiers = [NSMutableSet setWithArray:blacklistedDisplayIdentifiers];
    self.seenListenerNames = [NSMutableSet setWithArray:seenListenerNames];
    self.legacyPreferences = [legacyPreferences isKindOfClass:NSDictionary.class] ? [legacyPreferences mutableCopy]
                                                                                  : [[NSMutableDictionary alloc] init];
    self.storedCurrentProfileName = [currentProfileName copy];
}

#pragma mark - Listener Registry

- (id<LAListener>)listenerForName:(NSString *)name {
    if (name.length == 0) {
        return nil;
    }
    __block id<LAListener> listener = nil;
    dispatch_sync(self.stateQueue, ^{
        listener = self.listeners[name];
    });
    return listener;
}

- (BOOL)hasListenerWithName:(NSString *)name {
    return [self listenerForName:name] != nil;
}

- (BOOL)hasSeenListenerWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL seen = NO;
    dispatch_sync(self.stateQueue, ^{
        seen = [self.seenListenerNames containsObject:name];
    });
    return seen;
}

- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name {
    return [self registerListener:listener forName:name markSeen:YES];
}

- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name markSeen:(BOOL)markSeen {
    if (!listener || name.length == 0) {
        return NO;
    }
    __block BOOL added = NO;
    dispatch_sync(self.stateQueue, ^{
        added = self.listeners[name] == nil;
        self.listeners[name] = listener;
        if (added) {
            self.cachedListenerNames = nil;
        }
        if (markSeen && ![self.seenListenerNames containsObject:name]) {
            [self.seenListenerNames addObject:name];
            [self savePersistentState];
        }
    });
    return added;
}

- (BOOL)unregisterListenerWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL removed = NO;
    dispatch_sync(self.stateQueue, ^{
        removed = self.listeners[name] != nil;
        [self.listeners removeObjectForKey:name];
        if (removed) {
            self.cachedListenerNames = nil;
        }
    });
    return removed;
}

- (NSArray *)availableListenerNames {
    __block NSArray *listenerNames = nil;
    dispatch_sync(self.stateQueue, ^{
        if (!self.cachedListenerNames) {
            self.cachedListenerNames = [self.listeners.allKeys sortedArrayUsingSelector:@selector(compare:)];
        }
        listenerNames = self.cachedListenerNames;
    });
    return listenerNames;
}

- (NSArray *)registeredListeners {
    __block NSArray *listeners = nil;
    dispatch_sync(self.stateQueue, ^{
        NSHashTable *uniqueListeners = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
        for (id listener in self.listeners.allValues) {
            [uniqueListeners addObject:listener];
        }
        listeners = uniqueListeners.allObjects;
    });
    return listeners ?: @[];
}

#pragma mark - Event Registry

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }
    __block id<LAEventDataSource> dataSource = nil;
    dispatch_sync(self.stateQueue, ^{
        dataSource = self.eventDataSources[eventName];
    });
    return dataSource;
}

- (BOOL)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName {
    if (!dataSource || eventName.length == 0) {
        return NO;
    }
    __block BOOL added = NO;
    dispatch_sync(self.stateQueue, ^{
        added = self.eventDataSources[eventName] == nil;
        self.eventDataSources[eventName] = dataSource;
    });
    return added;
}

- (BOOL)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return NO;
    }
    __block BOOL removed = NO;
    dispatch_sync(self.stateQueue, ^{
        removed = self.eventDataSources[eventName] != nil;
        [self.eventDataSources removeObjectForKey:eventName];
    });
    return removed;
}

- (NSArray *)availableEventNames {
    __block NSArray *eventNames = nil;
    dispatch_sync(self.stateQueue, ^{
        eventNames = [self.eventDataSources.allKeys sortedArrayUsingSelector:@selector(compare:)];
    });
    return eventNames;
}

- (BOOL)hasEventWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL hasEvent = NO;
    dispatch_sync(self.stateQueue, ^{
        hasEvent = self.eventDataSources[name] != nil;
    });
    return hasEvent;
}

#pragma mark - Assignments

- (BOOL)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    return [self assignEventName:event.name mode:event.mode toListenerNames:listenerNames];
}

- (BOOL)assignEventName:(NSString *)eventName mode:(NSString *)mode toListenerNames:(NSArray *)listenerNames {
    if (eventName.length == 0) {
        return NO;
    }

    NSString *normalizedMode = mode ?: @"";
    NSArray *normalizedNames = [LARuntimeBackend normalizedStringArray:listenerNames];
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[eventName];
        if (!eventAssignments) {
            eventAssignments = [[NSMutableDictionary alloc] init];
            assignments[eventName] = eventAssignments;
        }

        if (normalizedNames.count > 0) {
            changed = ![eventAssignments[normalizedMode] isEqualToArray:normalizedNames];
            eventAssignments[normalizedMode] = normalizedNames;
        } else {
            changed = eventAssignments[normalizedMode] != nil;
            [eventAssignments removeObjectForKey:normalizedMode];
            if (eventAssignments.count == 0) {
                [assignments removeObjectForKey:eventName];
            }
        }
        if (changed) {
            [self savePersistentState];
        }
    });
    return changed;
}

- (BOOL)unassignEvent:(LAEvent *)event {
    return [self assignEvent:event toListenersWithNames:@[]];
}

- (BOOL)addListenerName:(NSString *)listenerName toEvent:(LAEvent *)event {
    if (listenerName.length == 0 || event.name.length == 0) {
        return NO;
    }

    NSString *mode = event.mode ?: @"";
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[event.name];
        if (!eventAssignments) {
            eventAssignments = [[NSMutableDictionary alloc] init];
            assignments[event.name] = eventAssignments;
        }

        NSMutableArray *listenerNames = [eventAssignments[mode] mutableCopy] ?: [[NSMutableArray alloc] init];
        if (![listenerNames containsObject:listenerName]) {
            [listenerNames addObject:listenerName];
            eventAssignments[mode] = [LARuntimeBackend normalizedStringArray:listenerNames];
            changed = YES;
            [self savePersistentState];
        }
    });
    return changed;
}

- (BOOL)removeListenerName:(NSString *)listenerName fromEvent:(LAEvent *)event {
    if (listenerName.length == 0 || event.name.length == 0) {
        return NO;
    }

    NSString *mode = event.mode ?: @"";
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[event.name];
        NSMutableArray *listenerNames = [eventAssignments[mode] mutableCopy];
        if (![listenerNames containsObject:listenerName]) {
            return;
        }

        [listenerNames removeObject:listenerName];
        if (listenerNames.count > 0) {
            eventAssignments[mode] = [LARuntimeBackend normalizedStringArray:listenerNames];
        } else {
            [eventAssignments removeObjectForKey:mode];
            if (eventAssignments.count == 0) {
                [assignments removeObjectForKey:event.name];
            }
        }
        changed = YES;
        [self savePersistentState];
    });
    return changed;
}

- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event {
    return [self assignedListenerNamesForEventName:event.name mode:event.mode];
}

- (NSArray *)assignedListenerNamesForEventName:(NSString *)eventName mode:(NSString *)mode {
    if (eventName.length == 0) {
        return @[];
    }

    NSString *normalizedMode = mode ?: @"";
    __block NSArray *listenerNames = nil;
    dispatch_sync(self.stateQueue, ^{
        NSDictionary *assignments = [self assignmentsForCurrentProfile];
        listenerNames = [assignments[eventName][normalizedMode] copy];
    });
    return listenerNames ?: @[];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray array];
    dispatch_sync(self.stateQueue, ^{
        NSDictionary *assignments = [self assignmentsForCurrentProfile];
        for (NSString *eventName in assignments) {
            NSDictionary *modes = assignments[eventName];
            for (NSString *mode in modes) {
                if ([modes[mode] containsObject:listenerName]) {
                    [events addObject:[LAEvent eventWithName:eventName mode:mode.length > 0 ? mode : nil]];
                }
            }
        }
    });
    return [events copy];
}

#pragma mark - Blacklist

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier {
    if (displayIdentifier.length == 0) {
        return NO;
    }
    __block BOOL blacklisted = NO;
    dispatch_sync(self.stateQueue, ^{
        blacklisted = [self.blacklistedDisplayIdentifiers containsObject:displayIdentifier];
    });
    return blacklisted;
}

- (BOOL)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    if (displayIdentifier.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        BOOL currentlyBlacklisted = [self.blacklistedDisplayIdentifiers containsObject:displayIdentifier];
        changed = currentlyBlacklisted != blacklisted;
        if (!changed) {
            return;
        }
        if (blacklisted) {
            [self.blacklistedDisplayIdentifiers addObject:displayIdentifier];
        } else {
            [self.blacklistedDisplayIdentifiers removeObject:displayIdentifier];
        }
        [self savePersistentState];
    });
    return changed;
}

#pragma mark - Legacy Preferences

- (BOOL)setListenerName:(NSString *)listenerName seen:(BOOL)seen {
    if (listenerName.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        BOOL currentlySeen = [self.seenListenerNames containsObject:listenerName];
        changed = currentlySeen != seen;
        if (!changed) {
            return;
        }
        if (seen) {
            [self.seenListenerNames addObject:listenerName];
        } else {
            [self.seenListenerNames removeObject:listenerName];
        }
        [self savePersistentState];
    });
    return changed;
}

- (id)objectForLegacyPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return nil;
    }
    __block id object = nil;
    dispatch_sync(self.stateQueue, ^{
        object = self.legacyPreferences[key];
    });
    return object;
}

- (BOOL)setObject:(id)object forLegacyPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        id existingObject = self.legacyPreferences[key];
        if (object) {
            changed = ![existingObject isEqual:object];
            if (changed) {
                self.legacyPreferences[key] = object;
            }
        } else {
            changed = existingObject != nil;
            if (changed) {
                [self.legacyPreferences removeObjectForKey:key];
            }
        }
        if (changed) {
            [self savePersistentState];
        }
    });
    return changed;
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    __block NSArray *profileNames = nil;
    dispatch_sync(self.stateQueue, ^{
        profileNames = [self.profiles.allKeys sortedArrayUsingSelector:@selector(compare:)];
    });
    return profileNames;
}

- (NSString *)currentProfileName {
    __block NSString *profileName = nil;
    dispatch_sync(self.stateQueue, ^{
        profileName = self.storedCurrentProfileName;
    });
    return profileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    [self setCurrentProfileNameIfChanged:currentProfileName];
}

- (BOOL)setCurrentProfileNameIfChanged:(NSString *)currentProfileName {
    NSString *profileName = currentProfileName.length > 0 ? [currentProfileName copy] : LAActivatorDefaultProfileName;
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        BOOL profileExists = self.profiles[profileName] != nil;
        changed = ![self.storedCurrentProfileName isEqualToString:profileName] || !profileExists;
        if (!changed) {
            return;
        }
        self.storedCurrentProfileName = profileName;
        [self assignmentsForCurrentProfile];
        [self savePersistentState];
    });
    return changed;
}

@end
