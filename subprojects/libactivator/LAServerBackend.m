//
//  LAServerBackend.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAServerBackend.h"

#import "LAPersistence.h"

#import <HBLog.h>
#import <dispatch/dispatch.h>

static NSString *const LAActivatorDefaultProfileName = @"Default";
static NSString *const LAActivatorSchemaVersionKey = @"SchemaVersion";
static NSString *const LAActivatorCurrentProfileNameKey = @"CurrentProfileName";
static NSString *const LAActivatorProfilesKey = @"Profiles";
static NSString *const LAActivatorAssignmentsKey = @"Assignments";
static NSString *const LAActivatorBlacklistedDisplayIdentifiersKey = @"BlacklistedDisplayIdentifiers";
static NSString *const LAActivatorSeenListenerNamesKey = @"SeenListenerNames";
static NSString *const LAActivatorLegacyPreferencesKey = @"LegacyPreferences";

@interface LAServerBackend ()

// Registries
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<LAEventDataSource>> *eventDataSources;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<LAListener>> *listeners;
@property(nonatomic, copy, nullable) NSArray<NSString *> *cachedListenerNames;

// State
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *profiles;
@property(nonatomic, strong) NSMutableSet<NSString *> *blacklistedDisplayIdentifiers;
@property(nonatomic, strong) NSMutableSet<NSString *> *seenListenerNames;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *legacyPreferences;
@property(nonatomic, copy) NSString *storedCurrentProfileName;

// Persistence
@property(nonatomic, strong) LAPersistence *persistence;
@property(nonatomic, assign) BOOL persistentStateDirty;
@property(nonatomic, assign) BOOL persistentSaveScheduled;
@property(nonatomic, assign, nullable) CFRunLoopObserverRef persistentSaveObserver;

// State protection
@property(nonatomic, strong) NSRecursiveLock *stateLock;

@end

@implementation LAServerBackend

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
        _stateLock = [[NSRecursiveLock alloc] init];
        _stateLock.name = @"libactivator.state";
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

    [self performWithStateLock:markDirty];
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

    [self performWithStateLock:copyPendingDictionary];

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

- (void)performWithStateLock:(dispatch_block_t)block {
    [self.stateLock lock];
    block();
    [self.stateLock unlock];
}

- (void)installPersistentSaveObserverIfNeeded {
    __block BOOL shouldInstall = NO;
    [self performWithStateLock:^{
        shouldInstall =
            self.persistentStateDirty && self.persistentSaveScheduled && self.persistentSaveObserver == NULL;
    }];
    if (!shouldInstall) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^handler)(CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
        ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            __block CFRunLoopObserverRef observerToInvalidate = NULL;
            [strongSelf performWithStateLock:^{
                observerToInvalidate = strongSelf.persistentSaveObserver;
                strongSelf.persistentSaveObserver = NULL;
            }];
            if (observerToInvalidate) {
                CFRunLoopObserverInvalidate(observerToInvalidate);
                CFRelease(observerToInvalidate);
            }
            [strongSelf flushPendingPersistentState];
        };

    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(
        kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, false, 0, handler);
    if (!observer) {
        [self flushPendingPersistentState];
        return;
    }

    __block BOOL shouldAddObserver = NO;
    [self performWithStateLock:^{
        if (self.persistentStateDirty && self.persistentSaveScheduled && self.persistentSaveObserver == NULL) {
            self.persistentSaveObserver = observer;
            shouldAddObserver = YES;
        }
    }];
    if (!shouldAddObserver) {
        CFRelease(observer);
        return;
    }

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
                    NSArray *listenerNames = [LAServerBackend normalizedStringArray:modes[mode]];
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
        [LAServerBackend normalizedStringArray:dictionary[LAActivatorBlacklistedDisplayIdentifiersKey]];
    NSArray *seenListenerNames = [LAServerBackend normalizedStringArray:dictionary[LAActivatorSeenListenerNamesKey]];
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
    [self performWithStateLock:^{
        listener = self.listeners[name];
    }];
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
    [self performWithStateLock:^{
        seen = [self.seenListenerNames containsObject:name];
    }];
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
    [self performWithStateLock:^{
        added = self.listeners[name] == nil;
        self.listeners[name] = listener;
        if (added) {
            self.cachedListenerNames = nil;
        }
        if (markSeen && ![self.seenListenerNames containsObject:name]) {
            [self.seenListenerNames addObject:name];
            [self savePersistentState];
        }
    }];
    return added;
}

- (BOOL)unregisterListenerWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL removed = NO;
    [self performWithStateLock:^{
        removed = self.listeners[name] != nil;
        [self.listeners removeObjectForKey:name];
        if (removed) {
            self.cachedListenerNames = nil;
        }
    }];
    return removed;
}

- (NSArray *)availableListenerNames {
    __block NSArray *listenerNames = nil;
    [self performWithStateLock:^{
        if (!self.cachedListenerNames) {
            self.cachedListenerNames = [self.listeners.allKeys sortedArrayUsingSelector:@selector(compare:)];
        }
        listenerNames = self.cachedListenerNames;
    }];
    return listenerNames;
}

- (NSArray *)registeredListeners {
    __block NSArray *listeners = nil;
    [self performWithStateLock:^{
        NSHashTable *uniqueListeners = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
        for (id listener in self.listeners.allValues) {
            [uniqueListeners addObject:listener];
        }
        listeners = uniqueListeners.allObjects;
    }];
    return listeners ?: @[];
}

#pragma mark - Event Registry

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }
    __block id<LAEventDataSource> dataSource = nil;
    [self performWithStateLock:^{
        dataSource = self.eventDataSources[eventName];
    }];
    return dataSource;
}

- (BOOL)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName {
    if (!dataSource || eventName.length == 0) {
        return NO;
    }
    __block BOOL added = NO;
    [self performWithStateLock:^{
        added = self.eventDataSources[eventName] == nil;
        self.eventDataSources[eventName] = dataSource;
    }];
    return added;
}

- (BOOL)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return NO;
    }
    __block BOOL removed = NO;
    [self performWithStateLock:^{
        removed = self.eventDataSources[eventName] != nil;
        [self.eventDataSources removeObjectForKey:eventName];
    }];
    return removed;
}

- (NSArray *)availableEventNames {
    __block NSArray *eventNames = nil;
    [self performWithStateLock:^{
        eventNames = [self.eventDataSources.allKeys sortedArrayUsingSelector:@selector(compare:)];
    }];
    return eventNames;
}

- (BOOL)hasEventWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL hasEvent = NO;
    [self performWithStateLock:^{
        hasEvent = self.eventDataSources[name] != nil;
    }];
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
    NSArray *normalizedNames = [LAServerBackend normalizedStringArray:listenerNames];
    __block BOOL changed = NO;
    [self performWithStateLock:^{
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
    }];
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
    [self performWithStateLock:^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[event.name];
        if (!eventAssignments) {
            eventAssignments = [[NSMutableDictionary alloc] init];
            assignments[event.name] = eventAssignments;
        }

        NSMutableArray *listenerNames = [eventAssignments[mode] mutableCopy] ?: [[NSMutableArray alloc] init];
        if (![listenerNames containsObject:listenerName]) {
            [listenerNames addObject:listenerName];
            eventAssignments[mode] = [LAServerBackend normalizedStringArray:listenerNames];
            changed = YES;
            [self savePersistentState];
        }
    }];
    return changed;
}

- (BOOL)removeListenerName:(NSString *)listenerName fromEvent:(LAEvent *)event {
    if (listenerName.length == 0 || event.name.length == 0) {
        return NO;
    }

    NSString *mode = event.mode ?: @"";
    __block BOOL changed = NO;
    [self performWithStateLock:^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[event.name];
        NSMutableArray *listenerNames = [eventAssignments[mode] mutableCopy];
        if (![listenerNames containsObject:listenerName]) {
            return;
        }

        [listenerNames removeObject:listenerName];
        if (listenerNames.count > 0) {
            eventAssignments[mode] = [LAServerBackend normalizedStringArray:listenerNames];
        } else {
            [eventAssignments removeObjectForKey:mode];
            if (eventAssignments.count == 0) {
                [assignments removeObjectForKey:event.name];
            }
        }
        changed = YES;
        [self savePersistentState];
    }];
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
    [self performWithStateLock:^{
        NSDictionary *assignments = [self assignmentsForCurrentProfile];
        listenerNames = [assignments[eventName][normalizedMode] copy];
    }];
    return listenerNames ?: @[];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray array];
    [self performWithStateLock:^{
        NSDictionary *assignments = [self assignmentsForCurrentProfile];
        for (NSString *eventName in assignments) {
            NSDictionary *modes = assignments[eventName];
            for (NSString *mode in modes) {
                if ([modes[mode] containsObject:listenerName]) {
                    [events addObject:[LAEvent eventWithName:eventName mode:mode.length > 0 ? mode : nil]];
                }
            }
        }
    }];
    return [events copy];
}

#pragma mark - Blacklist

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier {
    if (displayIdentifier.length == 0) {
        return NO;
    }
    __block BOOL blacklisted = NO;
    [self performWithStateLock:^{
        blacklisted = [self.blacklistedDisplayIdentifiers containsObject:displayIdentifier];
    }];
    return blacklisted;
}

- (BOOL)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    if (displayIdentifier.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    [self performWithStateLock:^{
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
    }];
    return changed;
}

#pragma mark - Legacy Preferences

- (BOOL)setListenerName:(NSString *)listenerName seen:(BOOL)seen {
    if (listenerName.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    [self performWithStateLock:^{
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
    }];
    return changed;
}

- (id)objectForLegacyPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return nil;
    }
    __block id object = nil;
    [self performWithStateLock:^{
        object = self.legacyPreferences[key];
    }];
    return object;
}

- (BOOL)setObject:(id)object forLegacyPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }
    __block BOOL changed = NO;
    [self performWithStateLock:^{
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
    }];
    return changed;
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    __block NSArray *profileNames = nil;
    [self performWithStateLock:^{
        profileNames = [self.profiles.allKeys sortedArrayUsingSelector:@selector(compare:)];
    }];
    return profileNames;
}

- (NSString *)currentProfileName {
    __block NSString *profileName = nil;
    [self performWithStateLock:^{
        profileName = self.storedCurrentProfileName;
    }];
    return profileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    [self setCurrentProfileNameIfChanged:currentProfileName];
}

- (BOOL)setCurrentProfileNameIfChanged:(NSString *)currentProfileName {
    NSString *profileName = currentProfileName.length > 0 ? [currentProfileName copy] : LAActivatorDefaultProfileName;
    __block BOOL changed = NO;
    [self performWithStateLock:^{
        BOOL profileExists = self.profiles[profileName] != nil;
        changed = ![self.storedCurrentProfileName isEqualToString:profileName] || !profileExists;
        if (!changed) {
            return;
        }
        self.storedCurrentProfileName = profileName;
        [self assignmentsForCurrentProfile];
        [self savePersistentState];
    }];
    return changed;
}

@end
