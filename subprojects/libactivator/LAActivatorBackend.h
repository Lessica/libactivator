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

@property(nonatomic, copy) NSString *currentProfileName;

- (instancetype)initWithPersistence:(nullable LAActivatorPersistence *)persistence;

- (nullable id<LAListener>)listenerForName:(NSString *)name;
- (BOOL)hasListenerWithName:(NSString *)name;
- (BOOL)hasSeenListenerWithName:(NSString *)name;
- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name;
- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name markSeen:(BOOL)markSeen;
- (BOOL)unregisterListenerWithName:(NSString *)name;
- (NSArray *)availableListenerNames;
- (NSArray *)registeredListeners;

- (nullable id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;
- (BOOL)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (BOOL)unregisterEventDataSourceWithEventName:(NSString *)eventName;
- (NSArray *)availableEventNames;
- (BOOL)hasEventWithName:(NSString *)name;

- (BOOL)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)addListenerName:(NSString *)listenerName toEvent:(LAEvent *)event;
- (BOOL)removeListenerName:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (BOOL)unassignEvent:(LAEvent *)event;
- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event;
- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName;

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier;
- (BOOL)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (NSArray *)availableProfileNames;
- (BOOL)setCurrentProfileNameIfChanged:(nullable NSString *)currentProfileName;

- (BOOL)flushPendingPersistentState;

+ (NSArray *)normalizedStringArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
