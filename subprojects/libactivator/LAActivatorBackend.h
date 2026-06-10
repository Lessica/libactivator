//
//  LAActivatorBackend.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivatorPersistence;

__attribute__((visibility("hidden")))
@interface LAActivatorBackend : NSObject

#pragma mark - Lifecycle

- (instancetype)initWithPersistence:(nullable LAActivatorPersistence *)persistence;

#pragma mark - Listener Registry

- (nullable id<LAListener>)listenerForName:(NSString *)name;
- (BOOL)hasListenerWithName:(NSString *)name;
- (BOOL)hasSeenListenerWithName:(NSString *)name;
- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name;
- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name markSeen:(BOOL)markSeen;
- (BOOL)unregisterListenerWithName:(NSString *)name;
- (NSArray<NSString *> *)availableListenerNames;
- (NSArray<id<LAListener>> *)registeredListeners;

#pragma mark - Event Registry

- (nullable id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;
- (BOOL)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (BOOL)unregisterEventDataSourceWithEventName:(NSString *)eventName;
- (NSArray<NSString *> *)availableEventNames;
- (BOOL)hasEventWithName:(NSString *)name;

#pragma mark - Assignment Model

- (BOOL)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (BOOL)assignEventName:(NSString *)eventName
                   mode:(nullable NSString *)mode
        toListenerNames:(NSArray<NSString *> *)listenerNames;
- (BOOL)addListenerName:(NSString *)listenerName toEvent:(LAEvent *)event;
- (BOOL)removeListenerName:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (BOOL)unassignEvent:(LAEvent *)event;
- (NSArray<NSString *> *)assignedListenerNamesForEvent:(LAEvent *)event;
- (NSArray<NSString *> *)assignedListenerNamesForEventName:(NSString *)eventName mode:(nullable NSString *)mode;
- (NSArray<LAEvent *> *)eventsAssignedToListenerWithName:(NSString *)listenerName;

#pragma mark - Blacklist And Legacy Preferences

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier;
- (BOOL)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)setListenerName:(NSString *)listenerName seen:(BOOL)seen;
- (nullable id)objectForLegacyPreferenceKey:(NSString *)key;
- (BOOL)setObject:(nullable id)object forLegacyPreferenceKey:(NSString *)key;

#pragma mark - Profiles

@property(nonatomic, copy) NSString *currentProfileName;

- (NSArray<NSString *> *)availableProfileNames;
- (BOOL)setCurrentProfileNameIfChanged:(nullable NSString *)currentProfileName;

#pragma mark - Persistence

- (BOOL)flushPendingPersistentState;

#pragma mark - Utilities

+ (NSArray<NSString *> *)normalizedStringArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
