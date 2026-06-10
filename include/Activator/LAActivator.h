//
//  LAActivator.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorVersion.h"

NS_ASSUME_NONNULL_BEGIN

// Main event dispatcher that is responsible for sending events, maintaining the list of actions/events, and querying
// information about them

@class UIImage;

@class LAEvent;
@class LAListenerConfigurationViewController;
@class LAEventConfigurationViewController;

@protocol LAListener;
@protocol LAEventDataSource;

@interface LAActivator : NSObject
LA_PRIVATE_IVARS(LAActivator)

#pragma mark - Lifecycle

+ (LAActivator *)sharedInstance;

#pragma mark - Runtime

@property(nonatomic, readonly) LAActivatorVersion version;
@property(nonatomic, readonly, getter=isRunningInsideSpringBoard) BOOL runningInsideSpringBoard;
@property(nonatomic, readonly, getter=isDangerousToSendEvents) BOOL dangerousToSendEvents LA_DEPRECATED(
    "dangerousToSendEvents is obsolete and always returns NO in libactivator 2.x");

#pragma mark - Listener Dispatch

- (nullable id<LAListener>)listenerForEvent:(LAEvent *)event;
- (void)sendEventToListener:(LAEvent *)event;
- (void)sendEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)sendEvent:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (void)sendAbortToListener:(LAEvent *)event;
- (void)sendAbortEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)sendAbortEvent:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (void)sendPreviewEventToListenerWithName:(NSString *)listenerName;
- (void)sendDeactivateEventToListeners:(LAEvent *)event;

#pragma mark - Listener Registry

- (nullable id<LAListener>)listenerForName:(NSString *)name;
- (BOOL)hasListenerWithName:(NSString *)name;
- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name; // Only available in SpringBoard
- (void)unregisterListenerWithName:(NSString *)name;                        // Only available in SpringBoard

- (BOOL)hasSeenListenerWithName:(NSString *)name;

#pragma mark - Assignments

// In this section, the LAEvent parameter is used as an assignment key: event.name plus event.mode selects the binding
// slot. When event.mode is nil, mutating APIs apply to all compatible modes, while query APIs resolve using the current
// event mode where appropriate.

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray<NSString *> *)listenerNames;
- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event;
- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (void)unassignEvent:(LAEvent *)event;
- (nullable NSString *)assignedListenerNameForEvent:(LAEvent *)event;
- (NSArray<NSString *> *)assignedListenerNamesForEvent:(LAEvent *)event;
- (NSArray<LAEvent *> *)eventsAssignedToListenerWithName:(NSString *)listenerName;

#pragma mark - Event Registry

// These APIs deal with event definitions, not dispatched LAEvent instances. An event definition is addressed by its
// NSString event name and is backed in SpringBoard by an LAEventDataSource that supplies metadata and capabilities.

@property(nonatomic, readonly) NSArray<NSString *> *availableEventNames;
- (BOOL)hasEventWithName:(NSString *)name;
- (BOOL)eventWithNameIsHidden:(NSString *)name;
- (BOOL)eventWithNameRequiresAssignment:(NSString *)name;
- (NSArray<NSString *> *)compatibleModesForEventWithName:(NSString *)name;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(nullable NSString *)eventMode;
- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName;
- (nullable NSString *)assignmentWarningForEventWithName:(NSString *)eventName;

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName;
- (void)removeEventWithName:(NSString *)eventName;

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName;

- (BOOL)eventWithNameSupportsConfiguration:(NSString *)eventName;
- (nullable LAEventConfigurationViewController *)configurationViewControllerForEventWithName:(NSString *)eventName;

#pragma mark - Listener Metadata

@property(nonatomic, readonly) NSArray<NSString *> *availableListenerNames;
- (nullable id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name;
- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name;
- (NSArray<NSString *> *)compatibleEventModesForListenerWithName:(NSString *)name;
- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(nullable NSString *)eventMode;
- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName;
- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName;
- (NSArray<NSString *> *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName;
- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray<NSString *> *)listenerNames;
- (nullable UIImage *)iconForListenerName:(NSString *)listenerName
    LA_DEPRECATED("Large listener icons are not supported.");
- (nullable UIImage *)smallIconForListenerName:(NSString *)listenerName;
- (nullable UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle;
- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName;
- (void)requestRemovalForListenerWithName:(NSString *)listenerName;

- (BOOL)listenerWithNameSupportsConfiguration:(NSString *)listenerName;
- (nullable LAListenerConfigurationViewController *)configurationViewControllerForListenerWithName:
    (NSString *)listenerName;

#pragma mark - Event Modes

@property(nonatomic, readonly) NSArray<NSString *> *availableEventModes;
@property(nonatomic, readonly) NSString *currentEventMode;
@property(nonatomic, readonly) NSString *currentEventModeUnderneathLockScreen;
@property(nonatomic, readonly) BOOL supportsUnlockingDeviceToSendEvents;

#pragma mark - Blacklisting

@property(nonatomic, readonly, nullable) NSString *displayIdentifierForCurrentApplication;
- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier;
- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;

#pragma mark - Profiles

@property(nonatomic, readonly) NSArray<NSString *> *availableProfileNames;
@property(nonatomic, copy) NSString *currentProfileName;

#pragma mark - Authorization

@property(nonatomic, readonly)
    LAAuthorizationStatus authorizationStatus LA_DEPRECATED("Legacy authorization is not implemented.");
- (void)requestAuthorization LA_DEPRECATED("Legacy authorization is not implemented.");

@end

extern LAActivator *LASharedActivator;

@interface LAActivator (Localization)

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value;

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode;
- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)localizedTitleForListenerNames:(NSArray<NSString *> *)listenerNames;

- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForListenerName:(NSString *)listenerName;

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName;

@end

extern NSString *const LAEventModeSpringBoard;
extern NSString *const LAEventModeApplication;
extern NSString *const LAEventModeLockScreen;

extern NSString *const LAActivatorAvailableListenersChangedNotification;
extern NSString *const LAActivatorAvailableEventsChangedNotification;
extern NSString *const LAActivatorAssignmentsChangedNotification;
extern NSString *const LAActivatorEventModeChangedNotification;
extern NSString *const LAActivatorAuthorizationChangedNotification;

NS_ASSUME_NONNULL_END
