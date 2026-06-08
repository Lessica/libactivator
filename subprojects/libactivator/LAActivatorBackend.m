//
//  LAActivatorBackend.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorBackend.h"

#import "LAActivatorPersistence.h"

#import <dispatch/dispatch.h>

static NSString *const LAActivatorDefaultProfileName = @"Default";
static NSString *const LAActivatorSchemaVersionKey = @"SchemaVersion";
static NSString *const LAActivatorCurrentProfileNameKey = @"CurrentProfileName";
static NSString *const LAActivatorProfilesKey = @"Profiles";
static NSString *const LAActivatorAssignmentsKey = @"Assignments";
static NSString *const LAActivatorBlacklistedDisplayIdentifiersKey = @"BlacklistedDisplayIdentifiers";
static NSString *const LAActivatorSeenListenerNamesKey = @"SeenListenerNames";

@interface LAActivatorBackend ()
@property(nonatomic, strong) NSMutableDictionary *eventDataSources;
@property(nonatomic, strong) NSMutableDictionary *listeners;
@property(nonatomic, strong) NSMutableDictionary *profiles;
@property(nonatomic, strong) NSMutableSet *blacklistedDisplayIdentifiers;
@property(nonatomic, strong) NSMutableSet *seenListenerNames;
@property(nonatomic, copy) NSArray *cachedListenerNames;
@property(nonatomic, strong) dispatch_queue_t stateQueue;
@property(nonatomic, strong) LAActivatorPersistence *persistence;
@end

@implementation LAActivatorBackend {
    NSString *_currentProfileName;
}

#pragma mark - Lifecycle

- (instancetype)initWithPersistence:(LAActivatorPersistence *)persistence {
    self = [super init];
    if (self) {
        _persistence = persistence;
        _eventDataSources = [[NSMutableDictionary alloc] init];
        _listeners = [[NSMutableDictionary alloc] init];
        _profiles = [[NSMutableDictionary alloc] init];
        _blacklistedDisplayIdentifiers = [[NSMutableSet alloc] init];
        _seenListenerNames = [[NSMutableSet alloc] init];
        _stateQueue = dispatch_queue_create("libactivator.state", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        [self resetRuntimeState];
        [self loadPersistentState];
    }
    return self;
}

- (void)resetRuntimeState {
    _currentProfileName = LAActivatorDefaultProfileName;
    self.profiles[LAActivatorDefaultProfileName] =
        [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
}

#pragma mark - Utilities

+ (NSArray *)normalizedStringArray:(NSArray *)array {
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![strings containsObject:value]) {
            [strings addObject:value];
        }
    }
    return [[strings sortedArrayUsingSelector:@selector(compare:)] copy];
}

- (NSMutableDictionary *)assignmentsForCurrentProfile {
    NSMutableDictionary *profile = self.profiles[_currentProfileName];
    if (!profile) {
        profile = [@{LAActivatorAssignmentsKey : [[NSMutableDictionary alloc] init]} mutableCopy];
        self.profiles[_currentProfileName] = profile;
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

    NSMutableDictionary *serializedProfiles = [[NSMutableDictionary alloc] init];
    for (NSString *profileName in self.profiles) {
        NSDictionary *profile = self.profiles[profileName];
        NSDictionary *assignments = profile[LAActivatorAssignmentsKey] ?: @{};
        serializedProfiles[profileName] = @{LAActivatorAssignmentsKey : assignments};
    }

    NSDictionary *dictionary = @{
        LAActivatorSchemaVersionKey : @1,
        LAActivatorCurrentProfileNameKey : _currentProfileName ?: LAActivatorDefaultProfileName,
        LAActivatorProfilesKey : serializedProfiles,
        LAActivatorBlacklistedDisplayIdentifiersKey :
            [self.blacklistedDisplayIdentifiers.allObjects sortedArrayUsingSelector:@selector(compare:)],
        LAActivatorSeenListenerNamesKey :
            [self.seenListenerNames.allObjects sortedArrayUsingSelector:@selector(compare:)],
    };
    [self.persistence saveDictionary:dictionary];
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
                    NSArray *listenerNames = [LAActivatorBackend normalizedStringArray:modes[mode]];
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
        [LAActivatorBackend normalizedStringArray:dictionary[LAActivatorBlacklistedDisplayIdentifiersKey]];
    NSArray *seenListenerNames = [LAActivatorBackend normalizedStringArray:dictionary[LAActivatorSeenListenerNamesKey]];
    self.profiles = loadedProfiles;
    self.blacklistedDisplayIdentifiers = [NSMutableSet setWithArray:blacklistedDisplayIdentifiers];
    self.seenListenerNames = [NSMutableSet setWithArray:seenListenerNames];
    _currentProfileName = [currentProfileName copy];
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
    if (event.name.length == 0) {
        return NO;
    }

    NSString *mode = event.mode ?: @"";
    NSArray *normalizedNames = [LAActivatorBackend normalizedStringArray:listenerNames];
    __block BOOL changed = NO;
    dispatch_sync(self.stateQueue, ^{
        NSMutableDictionary *assignments = [self assignmentsForCurrentProfile];
        NSMutableDictionary *eventAssignments = assignments[event.name];
        if (!eventAssignments) {
            eventAssignments = [[NSMutableDictionary alloc] init];
            assignments[event.name] = eventAssignments;
        }

        if (normalizedNames.count > 0) {
            changed = ![eventAssignments[mode] isEqualToArray:normalizedNames];
            eventAssignments[mode] = normalizedNames;
        } else {
            changed = eventAssignments[mode] != nil;
            [eventAssignments removeObjectForKey:mode];
            if (eventAssignments.count == 0) {
                [assignments removeObjectForKey:event.name];
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
            eventAssignments[mode] = [LAActivatorBackend normalizedStringArray:listenerNames];
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
            eventAssignments[mode] = [LAActivatorBackend normalizedStringArray:listenerNames];
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
    if (event.name.length == 0) {
        return @[];
    }

    NSString *mode = event.mode ?: @"";
    __block NSArray *listenerNames = nil;
    dispatch_sync(self.stateQueue, ^{
        NSDictionary *assignments = [self assignmentsForCurrentProfile];
        listenerNames = [assignments[event.name][mode] copy];
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
        profileName = _currentProfileName;
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
        changed = ![_currentProfileName isEqualToString:profileName] || !profileExists;
        if (!changed) {
            return;
        }
        _currentProfileName = profileName;
        [self assignmentsForCurrentProfile];
        [self savePersistentState];
    });
    return changed;
}

@end
