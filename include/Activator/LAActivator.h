//
//  LAActivator.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LAActivatorVersion.h"

NS_ASSUME_NONNULL_BEGIN

// Main event dispatcher that is responsible for sending events, maintaining the list of actions/events, and querying
// information about them

@class LAEvent;
@class LAListenerConfigurationViewController;
@class LAEventConfigurationViewController;

@protocol LAListener;
@protocol LAEventDataSource;

@interface LAActivator : NSObject
LA_PRIVATE_IVARS(LAActivator)

+ (LAActivator *)sharedInstance;

@property(nonatomic, readonly) LAActivatorVersion version;
@property(nonatomic, readonly, getter=isRunningInsideSpringBoard) BOOL runningInsideSpringBoard;
@property(nonatomic, readonly, getter=isDangerousToSendEvents) BOOL dangerousToSendEvents
    __attribute__((deprecated("dangerousToSendEvents is obsolete and always returns NO in libactivator 2.x")));

// Listeners

- (nullable id<LAListener>)listenerForEvent:(LAEvent *)event;
- (void)sendEventToListener:(LAEvent *)event;
- (void)sendEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)sendEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (void)sendAbortToListener:(LAEvent *)event;
- (void)sendAbortEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)sendAbortEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (void)sendPreviewEventToListenerWithName:(NSString *)listenerName;
- (void)sendDeactivateEventToListeners:(LAEvent *)event;

- (nullable id<LAListener>)listenerForName:(NSString *)name;
- (BOOL)hasListenerWithName:(NSString *)name;
- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name; // Only available in SpringBoard
- (void)unregisterListenerWithName:(NSString *)name;                        // Only available in SpringBoard

- (BOOL)hasSeenListenerWithName:(NSString *)name;

// Assignments

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName;
- (void)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event;
- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (void)unassignEvent:(LAEvent *)event;
- (nullable NSString *)assignedListenerNameForEvent:(LAEvent *)event;
- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event;
- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName;

// Events

@property(nonatomic, readonly) NSArray *availableEventNames;
- (BOOL)hasEventWithName:(NSString *)name;
- (BOOL)eventWithNameIsHidden:(NSString *)name;
- (BOOL)eventWithNameRequiresAssignment:(NSString *)name;
- (NSArray *)compatibleModesForEventWithName:(NSString *)name;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(nullable NSString *)eventMode;
- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName;

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName;
- (void)removeEventWithName:(NSString *)eventName;

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName;

- (BOOL)eventWithNameSupportsConfiguration:(NSString *)eventName;
- (nullable LAEventConfigurationViewController *)configurationViewControllerForEventWithName:(NSString *)eventName;

// Listener Metadata

@property(nonatomic, readonly) NSArray *availableListenerNames;
- (nullable id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name;
- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name;
- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name;
- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(nullable NSString *)eventMode;
- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName;
- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName;
- (NSArray *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName;
- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames;
- (nullable UIImage *)iconForListenerName:(NSString *)listenerName;
- (nullable UIImage *)smallIconForListenerName:(NSString *)listenerName;
- (nullable UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle;
- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName;
- (void)requestRemovalForListenerWithName:(NSString *)listenerName;

- (BOOL)listenerWithNameSupportsConfiguration:(NSString *)listenerName;
- (nullable LAListenerConfigurationViewController *)configurationViewControllerForListenerWithName:
    (NSString *)listenerName;

// Event Modes

@property(nonatomic, readonly) NSArray *availableEventModes;
@property(nonatomic, readonly) NSString *currentEventMode;
@property(nonatomic, readonly) NSString *currentEventModeUnderneathLockScreen;
@property(nonatomic, readonly) BOOL supportsUnlockingDeviceToSendEvents;

// Blacklisting

@property(nonatomic, readonly, nullable) NSString *displayIdentifierForCurrentApplication;
- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier;
- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;

// Profiles

@property(nonatomic, readonly) NSArray *availableProfileNames;
@property(nonatomic, copy) NSString *currentProfileName;

@end

extern LAActivator *LASharedActivator;

@interface LAActivator (Localization)
- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value;

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode;
- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)localizedTitleForListenerNames:(NSArray *)listenerNames;

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

NS_ASSUME_NONNULL_END
