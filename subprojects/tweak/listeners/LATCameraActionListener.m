//
//  LATCameraActionListener.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATCameraActionListener.h"

#import "LATApplicationLauncher.h"
#import "LATBuiltInRegistry.h"
#import "LATHIDEventSender.h"
#import "LATLockScreenCameraLauncher.h"
#import "LATRuntimeStateSource.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <notify.h>

static NSString *const LATCameraActionListenerNameInvokeShutter = @"libactivator.camera.invoke-shutter";
static NSString *const LATCameraActionSelectorInvokeShutter = @"cameraShutterWithActivator:event:";
static NSString *const LATCameraApplicationIdentifier = @"com.apple.camera";
static NSString *const LATCameraVolumeRegistrationChangedNotification =
    @"SBApplicationsRegisteredForVolumeButtonEventsChangedNotification";
static const char *LATCameraReadyNotification = "libactivator.camera.ready";
static const uint32_t LATCameraHIDPageConsumer = 0x0C;
static const uint32_t LATCameraHIDUsageVolumeDecrement = 0xEA;
static const NSTimeInterval LATCameraPendingShutterTimeout = 4.0;
static const NSTimeInterval LATLockScreenCameraReadyDelay = 0.6;

@interface SBApplication : NSObject
- (nullable NSString *)bundleIdentifier;
@end

@interface UIApplication (LATCameraActionListenerPrivate)
- (nullable NSArray<SBApplication *> *)appsRegisteredForVolumeEvents;
@end

@interface LATCameraActionListener ()

// Dependencies
@property(nonatomic, strong) LATApplicationLauncher *launcher;
@property(nonatomic, strong) LATLockScreenCameraLauncher *lockScreenCameraLauncher;
@property(nonatomic, strong) LATHIDEventSender *hidEventSender;
@property(nonatomic, weak, nullable) LATBuiltInRegistry *registry;

// Pending shutter state
@property(nonatomic, assign) BOOL pendingShutter;
@property(nonatomic, assign) BOOL pendingLockScreenCameraShutter;
@property(nonatomic, assign) NSUInteger pendingShutterGeneration;

// Notification state
@property(nonatomic, assign) int cameraReadyToken;
@property(nonatomic, strong, nullable) id volumeRegistrationObserver;

@end

@implementation LATCameraActionListener

#pragma mark - Lifecycle

- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher registry:(LATBuiltInRegistry *)registry {
    NSParameterAssert(launcher);

    self = [super init];
    if (self) {
        _launcher = launcher;
        _registry = registry;
        _lockScreenCameraLauncher = [[LATLockScreenCameraLauncher alloc] initWithRegistry:registry];
        _hidEventSender = [[LATHIDEventSender alloc] init];
        [self startObservingCameraReadyNotification];
        [self startObservingVolumeRegistrationNotification];
    }
    return self;
}

- (void)dealloc {
    if (self.cameraReadyToken != 0) {
        notify_cancel(self.cameraReadyToken);
    }
    if (self.volumeRegistrationObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:self.volumeRegistrationObserver];
    }
}

#pragma mark - Listener Metadata

+ (NSArray<NSString *> *)supportedListenerNames {
    return @[ LATCameraActionListenerNameInvokeShutter ];
}

+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    if ([listenerName isEqualToString:LATCameraActionListenerNameInvokeShutter]) {
        return LATCameraActionSelectorInvokeShutter;
    }
    return nil;
}

+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator {
    NSString *expectedSelector = [self expectedSelectorForListenerName:listenerName];
    if (listenerName.length == 0 || expectedSelector.length == 0) {
        return NO;
    }

    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:expectedSelector];
}

#pragma mark - LAListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    if (![listenerName isEqualToString:LATCameraActionListenerNameInvokeShutter]) {
        HBLogWarn(@"Camera action %@ is not supported by this listener", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerSelectorMatchesMetadataForActivator:activator]) {
        HBLogWarn(@"Camera action %@ metadata selector does not match %@", listenerName ?: @"",
                  LATCameraActionSelectorInvokeShutter);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self performCameraShutterForEvent:event activator:activator];
    });
}

#pragma mark - Metadata Validation

- (BOOL)listenerSelectorMatchesMetadataForActivator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector"
                                  forListenerWithName:LATCameraActionListenerNameInvokeShutter];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:LATCameraActionSelectorInvokeShutter];
}

#pragma mark - Shutter Flow

- (void)performCameraShutterForEvent:(LAEvent *)event activator:(LAActivator *)activator {
    if ([self shouldOpenLockScreenCameraForEvent:event activator:activator] ||
        [self.lockScreenCameraLauncher isLockScreenCameraVisible]) {
        [self beginPendingShutterForLockScreenCamera:YES];
        if ([self.lockScreenCameraLauncher isLockScreenCameraVisible]) {
            [self schedulePendingLockScreenCameraShutterCompletionWithReason:@"lock screen camera already visible"];
            return;
        }

        if ([self.lockScreenCameraLauncher enqueueOpenLockScreenCameraWithCompletion:^{
                [self schedulePendingLockScreenCameraShutterCompletionWithReason:
                          @"lock screen camera activation completed"];
            }]) {
            return;
        }

        [self cancelPendingShutterWithReason:@"Lock screen camera launch failed"];
        return;
    }

    LATRuntimeStateSource *runtimeStateSource = self.registry.runtimeStateSource;
    [runtimeStateSource refreshForegroundDisplayIdentifier];

    if ([runtimeStateSource.displayIdentifierForCurrentApplication isEqualToString:LATCameraApplicationIdentifier]) {
        [self sendCameraShutterHIDWithReason:@"camera foreground"];
        return;
    }

    [self beginPendingShutterForLockScreenCamera:NO];
    if (![self.launcher enqueueLaunchApplicationWithIdentifier:LATCameraApplicationIdentifier]) {
        [self cancelPendingShutterWithReason:@"Camera launch failed"];
    }
}

- (BOOL)shouldOpenLockScreenCameraForEvent:(LAEvent *)event activator:(LAActivator *)activator {
    NSString *eventMode = event.mode ?: activator.currentEventMode;
    if ([eventMode isEqualToString:LAEventModeLockScreen]) {
        return YES;
    }

    return self.registry.runtimeStateSource.isUILocked;
}

- (void)completePendingShutterIfNeeded {
    if (!self.pendingShutter) {
        return;
    }

    if (self.pendingLockScreenCameraShutter) {
        [self schedulePendingLockScreenCameraShutterCompletionWithReason:@"camera ready notification while locked"];
        return;
    }

    LATRuntimeStateSource *runtimeStateSource = self.registry.runtimeStateSource;
    [runtimeStateSource refreshForegroundDisplayIdentifier];

    if ([runtimeStateSource.displayIdentifierForCurrentApplication isEqualToString:LATCameraApplicationIdentifier]) {
        if ([self sendCameraShutterHIDWithReason:@"camera ready"]) {
            self.pendingShutter = NO;
        }
        return;
    }

    [self cancelPendingShutterWithReason:@"Camera ready arrived while Camera was not foreground"];
}

- (void)completePendingLockScreenCameraShutterIfNeeded {
    if (!self.pendingShutter) {
        return;
    }

    if (![self.lockScreenCameraLauncher isLockScreenCameraVisible]) {
        return;
    }

    if (![self cameraIsRegisteredForVolumeButtonEvents]) {
        HBLogDebug(@"Waiting for Camera volume button registration before lock screen camera shutter");
        return;
    }

    if ([self sendCameraShutterHIDWithReason:@"lock screen camera ready"]) {
        self.pendingShutter = NO;
        self.pendingLockScreenCameraShutter = NO;
    }
}

- (void)schedulePendingLockScreenCameraShutterCompletionWithReason:(NSString *)reason {
    if (!self.pendingShutter || !self.pendingLockScreenCameraShutter) {
        return;
    }

    NSUInteger generation = self.pendingShutterGeneration;
    HBLogDebug(@"Scheduling lock screen camera shutter completion after %.1fs: %@", LATLockScreenCameraReadyDelay,
               reason ?: @"");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATLockScreenCameraReadyDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       if (!self.pendingShutter || !self.pendingLockScreenCameraShutter ||
                           self.pendingShutterGeneration != generation) {
                           return;
                       }
                       [self completePendingLockScreenCameraShutterIfNeeded];
                   });
}

- (BOOL)sendCameraShutterHIDWithReason:(NSString *)reason {
    if (![self cameraIsRegisteredForVolumeButtonEvents]) {
        HBLogWarn(@"Skipping Camera shutter HID because Camera has not registered for volume button events: %@",
                  reason ?: @"");
        return NO;
    }

    if (![self.hidEventSender sendKeyboardUsagePage:LATCameraHIDPageConsumer
                                              usage:LATCameraHIDUsageVolumeDecrement
                                             reason:reason]) {
        HBLogError(@"Unable to send Camera shutter HID event for %@", reason ?: @"");
        return NO;
    }
    return YES;
}

- (BOOL)cameraIsRegisteredForVolumeButtonEvents {
    UIApplication *application = UIApplication.sharedApplication;
    if (![application respondsToSelector:@selector(appsRegisteredForVolumeEvents)]) {
        HBLogWarn(@"Unable to inspect volume button registration because SpringBoard does not expose "
                  @"appsRegisteredForVolumeEvents");
        return NO;
    }

    NSArray<SBApplication *> *registeredApplications = [application appsRegisteredForVolumeEvents];
    SBApplication *registeredApplication = registeredApplications.firstObject;
    if (![registeredApplication respondsToSelector:@selector(bundleIdentifier)]) {
        return NO;
    }

    NSString *bundleIdentifier = [(SBApplication *)registeredApplication bundleIdentifier];
    BOOL registeredForCamera = [bundleIdentifier isEqualToString:LATCameraApplicationIdentifier];
    if (!registeredForCamera) {
        HBLogDebug(@"Volume button events are registered for %@", bundleIdentifier ?: @"no application");
    }
    return registeredForCamera;
}

#pragma mark - Pending Shutter State

- (void)beginPendingShutterForLockScreenCamera:(BOOL)lockScreenCamera {
    self.pendingShutter = YES;
    self.pendingLockScreenCameraShutter = lockScreenCamera;
    self.pendingShutterGeneration++;
    NSUInteger generation = self.pendingShutterGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATCameraPendingShutterTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       if (!self.pendingShutter || self.pendingShutterGeneration != generation) {
                           return;
                       }
                       [self cancelPendingShutterWithReason:@"Camera ready timed out"];
                   });
}

- (void)cancelPendingShutterWithReason:(NSString *)reason {
    if (!self.pendingShutter) {
        return;
    }
    self.pendingShutter = NO;
    self.pendingLockScreenCameraShutter = NO;
    HBLogWarn(@"Dropping pending Camera shutter request: %@", reason ?: @"unknown reason");
}

#pragma mark - Camera Ready Notification

- (void)startObservingCameraReadyNotification {
    __weak typeof(self) weakSelf = self;
    int token = 0;
    int status =
        notify_register_dispatch(LATCameraReadyNotification, &token, dispatch_get_main_queue(), ^(int deliveredToken) {
            (void)deliveredToken;
            [weakSelf completePendingShutterIfNeeded];
        });
    if (status != NOTIFY_STATUS_OK) {
        HBLogWarn(@"Unable to observe Camera ready notification: %d", status);
        return;
    }

    self.cameraReadyToken = token;
}

- (void)startObservingVolumeRegistrationNotification {
    __weak typeof(self) weakSelf = self;
    self.volumeRegistrationObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:LATCameraVolumeRegistrationChangedNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *notification) {
                    [weakSelf
                        schedulePendingLockScreenCameraShutterCompletionWithReason:@"volume registration changed"];
                }];
}

@end
