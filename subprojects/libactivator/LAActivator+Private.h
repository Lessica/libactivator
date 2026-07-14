//
//  LAActivator+Private.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class LARuntimeContext;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LAActivatorListenerRegistryChangedNotification;
extern NSString *const LAActivatorEventRegistryChangedNotification;

@interface LAActivator (Private)

#pragma mark - Lifecycle

- (void)startIPCServerIfNeeded;

#pragma mark - Runtime State

- (nullable LARuntimeContext *)la_runtimeContext;
- (BOOL)la_isSpringBoardServiceReachable;
#if LIBACTIVATOR_TEST_SUPPORT
- (BOOL)la_flushPendingPersistentState;
#endif

#pragma mark - Device Capabilities

- (BOOL)la_hasRealHomeButton;

#pragma mark - Application Accessibility

- (BOOL)la_applicationAccessibilityEnabled;
- (BOOL)la_setApplicationAccessibilityEnabled:(BOOL)enabled;

#pragma mark - Legacy Preferences

- (nullable id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(nullable id)value forPreference:(NSString *)preference;

#pragma mark - Listener And Event Registration

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen;
- (nullable id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;
- (void)la_beginEventRegistryMutation;
- (void)la_endEventRegistryMutation;
- (BOOL)la_registerEventDataSourceIfAbsent:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (BOOL)la_unregisterEventDataSourceWithEventName:(NSString *)eventName
                              ifOwnedByDataSource:(id<LAEventDataSource>)dataSource;

#pragma mark - Event Configuration

- (nullable NSDictionary<NSString *, NSString *> *)la_eventConfigurationDescriptorForEventName:(NSString *)eventName;
- (nullable id)la_configurationForEventWithName:(NSString *)eventName;
- (BOOL)la_saveConfiguration:(id)configuration forEventWithName:(NSString *)eventName;

#pragma mark - Assignment Model

- (BOOL)la_assignEventAndNotifyIfChanged:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (BOOL)la_addListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName toEvent:(LAEvent *)event;
- (BOOL)la_removeListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (BOOL)la_unassignEventAndNotifyIfChanged:(LAEvent *)event;
- (BOOL)la_unassignEventNameFromAllProfilesAndNotifyIfChanged:(NSString *)eventName;
#if DEBUG || LIBACTIVATOR_TEST_SUPPORT
- (NSDictionary<NSString *, NSDictionary<NSString *, NSArray<NSString *> *> *> *)la_debugAssignmentSnapshot;
- (BOOL)la_debugResetAssignmentsAndNotifyIfChanged;
#endif

#pragma mark - Profiles And Blacklist

- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(nullable NSString *)currentProfileName;

#pragma mark - Event Dispatch Helpers

- (nullable NSData *)la_smallIconDataForListenerName:(NSString *)listenerName scale:(nullable CGFloat *)scale;
- (void)la_sendEvent:(LAEvent *)event directlyToListenerWithName:(NSString *)listenerName abort:(BOOL)abort;

#pragma mark - Statistics

#if DEBUG || LIBACTIVATOR_TEST_SUPPORT
- (NSDictionary<NSString *, NSNumber *> *)la_eventDispatchCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_listenerReceiveCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_eventAbortCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_listenerAbortCounts;
- (void)la_resetDispatchCounts;
#endif

@end

NS_ASSUME_NONNULL_END
