//
//  LAActivator+Private.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LAActivator (Private)

#pragma mark - Lifecycle

- (void)startIPCServerIfNeeded;

#pragma mark - Legacy Preferences

- (nullable id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(nullable id)value forPreference:(NSString *)preference;

#pragma mark - Listener And Event Registration

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen;
- (nullable id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;

#pragma mark - Runtime State

- (void)la_updateRuntimeEventMode:(NSString *)eventMode
             underneathLockScreen:(NSString *)underneathMode
                displayIdentifier:(nullable NSString *)displayIdentifier
                         screenOn:(BOOL)screenOn;
- (void)la_setSystemTouchActivityProvider:(nullable BOOL (^)(void))touchActiveProvider
                    touchesEndedPerformer:(nullable void (^)(dispatch_block_t block))touchesEndedPerformer;
#if LA_TESTING
- (NSDictionary<NSString *, id> *)la_runtimeStateDebugDictionary;
#endif

#pragma mark - Assignment Model

- (BOOL)la_assignEventAndNotifyIfChanged:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (BOOL)la_addListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName toEvent:(LAEvent *)event;
- (BOOL)la_removeListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (BOOL)la_unassignEventAndNotifyIfChanged:(LAEvent *)event;

#pragma mark - Profiles And Blacklist

- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(nullable NSString *)currentProfileName;

#pragma mark - Event Dispatch Helpers

- (nullable NSData *)la_smallIconDataForListenerName:(NSString *)listenerName scale:(nullable CGFloat *)scale;
- (void)la_sendEvent:(LAEvent *)event directlyToListenerWithName:(NSString *)listenerName abort:(BOOL)abort;

@end

NS_ASSUME_NONNULL_END
