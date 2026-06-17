//
//  LAListener.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class LAActivator, LAEvent, UIImage;

NS_ASSUME_NONNULL_BEGIN

// Listeners represent specific actions that can be performed in response to an event
// Must be registered with LAActivator inside SpringBoard via the registerListener:forName: method

@protocol LAListener <NSObject>
@optional

#pragma mark - Runtime Notifications

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode;

#pragma mark - Incoming Events

// Normal assigned events
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName;

// Sent when a chorded event gets escalated (short hold becomes a long hold, for example)
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName;

// Sent at the lock screen when listener is not compatible with event, but potentially is able to unlock the screen to
// handle it
- (BOOL)activator:(LAActivator *)activator
    receiveUnlockingDeviceEvent:(LAEvent *)event
                forListenerName:(NSString *)listenerName;

// Sent when the menu button is pressed. Only handle if you want to suppress the standard menu button behaviour!
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event;

// Sent when another listener has handled the event
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event;

// Sent from the settings pane when a listener is assigned
- (void)activator:(LAActivator *)activator receivePreviewEventForListenerName:(NSString *)listenerName;

// Simpler versions
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;

#pragma mark - Metadata (May Be Cached)

- (nullable NSString *)activator:(LAActivator *)activator
    requiresLocalizedTitleForListenerName:(NSString *)listenerName;
- (nullable NSString *)activator:(LAActivator *)activator
    requiresLocalizedDescriptionForListenerName:(NSString *)listenerName;
- (nullable NSString *)activator:(LAActivator *)activator
    requiresLocalizedGroupForListenerName:(NSString *)listenerName;
- (nullable NSNumber *)activator:(LAActivator *)activator
    requiresRequiresAssignmentForListenerName:(NSString *)listenerName;
- (nullable NSArray<NSString *> *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName;
- (nullable NSNumber *)activator:(LAActivator *)activator
    requiresIsCompatibleWithEventName:(NSString *)eventName
                         listenerName:(NSString *)listenerName;
- (nullable NSArray<NSString *> *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName;
- (nullable id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName;
- (BOOL)activator:(LAActivator *)activator requiresNeedsPoweredDisplayForListenerName:(NSString *)listenerName;

#pragma mark - Icons

// Fast path that supports scale
- (nullable NSData *)activator:(LAActivator *)activator
    requiresSmallIconDataForListenerName:(NSString *)listenerName
                                   scale:(nullable CGFloat *)scale;
// Legacy
- (nullable NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName;

// For cases where PNG data isn't available quickly
- (nullable UIImage *)activator:(LAActivator *)activator
    requiresSmallIconForListenerName:(NSString *)listenerName
                               scale:(CGFloat)scale;

- (nullable id)activator:(LAActivator *)activator requiresGlyphImageDescriptorForListenerName:(NSString *)listenerName;

- (BOOL)activator:(LAActivator *)activator requiresSupportsRemovalForListenerWithName:(NSString *)listenerName;
- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName;

// LAListenerConfigurationViewController
#pragma mark - Configuration

- (nullable NSString *)activator:(LAActivator *)activator
    requiresConfigurationViewControllerClassNameForListenerWithName:(NSString *)listenerName
                                                             bundle:(NSBundle *_Nullable *_Nullable)outBundle;

- (nullable id)activator:(LAActivator *)activator requestsConfigurationForListenerWithName:(NSString *)listenerName;
- (void)activator:(LAActivator *)activator
    didSaveNewConfiguration:(id)configuration
        forListenerWithName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
