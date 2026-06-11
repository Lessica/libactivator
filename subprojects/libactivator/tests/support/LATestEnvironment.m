//
//  LATestEnvironment.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEnvironment.h"

#import "LAActivator+Private.h"
#import "LARuntimeContext.h"
#import "LATestPrivateInterfaces.h"

#import <Activator/Activator.h>
#import <IOKit/hid/IOHIDEvent.h>
#import <IOKit/hid/IOHIDEventSystemClient.h>
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <roothide.h>

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

static const IOHIDEventField LATestHIDEventFieldIsBuiltIn = IOHIDEventFieldBase(kIOHIDEventTypeNULL) + 4;
static const IOHIDEventField LATestHIDEventFieldDigitizerIsDisplayIntegrated = kIOHIDEventFieldDigitizerMajorRadius + 5;
static const uint64_t LATestHIDSenderID = 0x8000000817319371;

@implementation LATestEnvironment

#pragma mark - Cleanup

+ (NSArray<NSString *> *)testListenerNames {
    return @[
        @"libactivator.test.listener.a",
        @"libactivator.test.listener.b",
        @"libactivator.test.listener.c",
        @"libactivator.test.listener.unseen",
        @"libactivator.test.listener.new",
        @"libactivator.test.listener.localization",
        @"libactivator.test.listener.icon",
        @"libactivator.test.dispatch.a",
        @"libactivator.test.dispatch.b",
        @"libactivator.test.dispatch.shared.first",
        @"libactivator.test.dispatch.shared.second",
        @"libactivator.test.dispatch.simple-abort",
        @"libactivator.test.dispatch.lock",
        @"libactivator.test.dispatch.unlock",
        @"libactivator.test.client-facade.user-info",
        @"libactivator.test.url.missing",
        @"libactivator.test.url.invalid",
    ];
}

+ (NSArray<NSString *> *)testEventNames {
    return @[
        @"libactivator.test.core",
        @"libactivator.test.removable-event",
        @"libactivator.test.nonremovable-event",
        @"libactivator.test.new-event-data-source",
        @"libactivator.test.dispatch",
        @"libactivator.test.built-in.nothing",
        @"libactivator.test.built-in.url",
        @"libactivator.test.client-facade.user-info",
    ];
}

+ (void)cleanActivator:(LAActivator *)activator {
    for (NSString *listenerName in [self testListenerNames]) {
        [activator unregisterListenerWithName:listenerName];
    }

    for (NSString *eventName in [self testEventNames]) {
        [activator unregisterEventDataSourceWithEventName:eventName];
        for (NSString *mode in activator.availableEventModes) {
            [activator unassignEvent:[LAEvent eventWithName:eventName mode:mode]];
        }
    }
    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [activator setCurrentProfileName:@"Default"];
    [self sendSyntheticTouchWithTouching:NO];
    [self waitForSyntheticTouchDelivery];
}

+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator {
    [[LARuntimeContext sharedContext] updateEventMode:LAEventModeSpringBoard
                                 underneathLockScreen:LAEventModeSpringBoard
                                    displayIdentifier:nil
                                             screenOn:YES];
}

+ (void)removeTestPlist {
    [NSFileManager.defaultManager removeItemAtPath:jbroot(@"/var/mobile/Library/Preferences/libactivator.tests.plist")
                                             error:nil];
}

#pragma mark - Synthetic Touches

+ (void)sendSyntheticTouchWithTouching:(BOOL)touching {
    uint64_t machTimeValue = mach_absolute_time();
    AbsoluteTime machTime;
#if TARGET_RT_BIG_ENDIAN
    machTime.hi = (UInt32)(machTimeValue >> 32);
    machTime.lo = (UInt32)machTimeValue;
#else
    machTime.lo = (UInt32)machTimeValue;
    machTime.hi = (UInt32)(machTimeValue >> 32);
#endif
    uint32_t eventMask = kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventRange | kIOHIDDigitizerEventIdentity;
    IOHIDEventRef event =
        IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, machTime, kIOHIDDigitizerTransducerTypeHand, 0, 0,
                                       eventMask, 0, 0, 0, 0, 0, 0, touching, touching, 0);
    if (!event) {
        return;
    }

    IOHIDEventSetIntegerValue(event, LATestHIDEventFieldIsBuiltIn, 1);
    IOHIDEventSetIntegerValue(event, LATestHIDEventFieldDigitizerIsDisplayIntegrated, 1);

    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, machTime, 2, 2, eventMask, 0.5,
                                                                0.5, 0, 0, 90.0, touching, touching, 0);
    if (finger) {
        IOHIDEventSetFloatValue(finger, kIOHIDEventFieldDigitizerMinorRadius, 5.0);
        IOHIDEventSetFloatValue(finger, kIOHIDEventFieldDigitizerMajorRadius, 5.0);
        IOHIDEventAppendEvent(event, finger);
        CFRelease(finger);
    }

    static IOHIDEventSystemClientRef sClient = nil;
    static dispatch_once_t sClientOnceToken;
    dispatch_once(&sClientOnceToken, ^{
        sClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    });

    static dispatch_queue_t sQueue = nil;
    static dispatch_once_t sQueueOnceToken;
    dispatch_once(&sQueueOnceToken, ^{
        sQueue = dispatch_queue_create("libactivator.tests.hid-events", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    });

    IOHIDEventRef eventToDispatch = (IOHIDEventRef)CFRetain(event);
    dispatch_async(sQueue, ^{
        IOHIDEventSetSenderID(eventToDispatch, LATestHIDSenderID);
        IOHIDEventSystemClientDispatchEvent(sClient, eventToDispatch);
        CFRelease(eventToDispatch);
    });
    CFRelease(event);
}

+ (void)waitForSyntheticTouchDelivery {
    [self waitAllowingMainRunLoopForTimeInterval:0.25];
    [self waitForMainQueue];
}

#pragma mark - Device Automation

+ (BOOL)resetHomeScreen {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class automationClass = NSClassFromString(@"SBSTestAutomationService");
        id service = automationClass ? [[automationClass alloc] init] : nil;
        if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)]) {
            [service resetToHomeScreenAnimated:NO useSafeTransitions:YES];
            attempted = YES;
        } else if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:)]) {
            [service resetToHomeScreenAnimated:NO];
            attempted = YES;
        } else {
            Class springBoardClass = NSClassFromString(@"SpringBoard");
            id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                                 ? [springBoardClass sharedApplication]
                                 : UIApplication.sharedApplication;
            if ([springBoard respondsToSelector:@selector(suspend)]) {
                [springBoard suspend];
                attempted = YES;
            }
        }
    }];
    return attempted;
}

+ (BOOL)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    __block BOOL opened = NO;
    [self performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                             ? [springBoardClass sharedApplication]
                             : UIApplication.sharedApplication;
        if ([springBoard respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
            [springBoard launchApplicationWithIdentifier:bundleIdentifier suspended:NO];
            opened = YES;
        }
    }];
    return opened;
}

+ (BOOL)prepareApplicationModeWithBundleIdentifier:(NSString *)bundleIdentifier
                                         activator:(LAActivator *)activator
                                          attempts:(NSUInteger)attempts {
    BOOL openedAtLeastOnce = NO;
    NSUInteger effectiveAttempts = attempts > 0 ? attempts : 1;
    for (NSUInteger attempt = 0; attempt < effectiveAttempts; attempt++) {
        if (![self openApplicationWithBundleIdentifier:bundleIdentifier]) {
            continue;
        }
        openedAtLeastOnce = YES;
        [self waitForFrontMostApplicationWithBundleIdentifier:bundleIdentifier timeout:5.0];
        [self waitAllowingMainRunLoopForTimeInterval:0.75];
        [self waitForMainQueue];
        if ([activator.currentEventMode isEqualToString:LAEventModeApplication] &&
            [activator.displayIdentifierForCurrentApplication isEqualToString:bundleIdentifier]) {
            return YES;
        }
        if (attempt + 1 < effectiveAttempts && [self resetHomeScreen]) {
            [self waitAllowingMainRunLoopForTimeInterval:1.0];
            [self waitForMainQueue];
        }
    }
    return openedAtLeastOnce;
}

+ (BOOL)suspendApplication {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                             ? [springBoardClass sharedApplication]
                             : UIApplication.sharedApplication;
        if ([springBoard respondsToSelector:@selector(suspend)]) {
            [springBoard suspend];
            attempted = YES;
        }
    }];
    return attempted;
}

+ (BOOL)lockDevice {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(remoteLock:)]) {
            [manager remoteLock:YES];
            attempted = YES;
            Class backlightClass = NSClassFromString(@"SBBacklightController");
            id backlight =
                [backlightClass respondsToSelector:@selector(sharedInstance)] ? [backlightClass sharedInstance] : nil;
            if ([backlight respondsToSelector:@selector(_startFadeOutAnimationFromLockSource:)]) {
                [backlight _startFadeOutAnimationFromLockSource:1];
            }
            return;
        }
    }];
    return attempted;
}

+ (BOOL)unlockDeviceWithPasscode:(NSString *)passcode {
    __block BOOL attempted = NO;
    NSString *passcodeToUse = [passcode copy] ?: @"";
    [self performOnMainThreadSynchronously:^{
        attempted = [self attemptUnlockOnMainThreadWithPasscode:passcodeToUse fallbackToHomeScreen:YES];
    }];
    return attempted;
}

+ (BOOL)attemptUnlockOnMainThreadWithPasscode:(NSString *)passcode fallbackToHomeScreen:(BOOL)fallbackToHomeScreen {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @"" finishUIUnlock:YES completion:nil];
        return YES;
    }
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @""];
        return YES;
    }
    if (fallbackToHomeScreen) {
        return [self resetHomeScreen];
    }
    return NO;
}

#pragma mark - Runtime State

+ (BOOL)isDeviceLocked {
    __block BOOL locked = NO;
    void (^readLockState)(void) = ^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(isUILocked)]) {
            locked = [manager isUILocked];
        }
    };
    [self performOnMainThreadSynchronously:readLockState];
    return locked;
}

+ (NSString *)frontMostDisplayIdentifier {
    __block NSString *displayIdentifier = nil;
    void (^readFrontMostApplication)(void) = ^{
        UIApplication *application = UIApplication.sharedApplication;
        if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
            return;
        }

        SBApplication *frontMostApplication = (SBApplication *)[application _accessibilityFrontMostApplication];
        if ([frontMostApplication respondsToSelector:@selector(bundleIdentifier)]) {
            displayIdentifier = [frontMostApplication bundleIdentifier];
        }
        if (displayIdentifier.length == 0 && [frontMostApplication respondsToSelector:@selector(displayIdentifier)]) {
            displayIdentifier = [frontMostApplication displayIdentifier];
        }
    };
    [self performOnMainThreadSynchronously:readFrontMostApplication];
    return displayIdentifier;
}

+ (BOOL)waitForFrontMostApplicationWithBundleIdentifier:(NSString *)bundleIdentifier timeout:(NSTimeInterval)timeout {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        if ([[self frontMostDisplayIdentifier] isEqualToString:bundleIdentifier]) {
            return YES;
        }
        [self waitAllowingMainRunLoopForTimeInterval:0.1];
    }
    return [[self frontMostDisplayIdentifier] isEqualToString:bundleIdentifier];
}

+ (NSString *)runtimeDebugReasonWithPrefix:(NSString *)prefix activator:(LAActivator *)activator {
    NSDictionary *state = [[LARuntimeContext sharedContext] testingDebugDictionary];
    return [NSString stringWithFormat:@"%@; mode=%@; homeSources=%@; springBoardSources=%@; lockSources=%@; "
                                      @"screenOn=%@; uiLocked=%@; frontMost=%@",
                                      prefix ?: @"Runtime mode mismatch", state[@"Mode"] ?: @"",
                                      state[@"HomeSources"] ?: @[], state[@"SpringBoardInterfaceSources"] ?: @[],
                                      state[@"LockSources"] ?: @[], state[@"ScreenOn"] ?: @NO,
                                      state[@"UILocked"] ?: @NO, state[@"FrontMost"] ?: @""];
}

#pragma mark - Synchronization Helpers

+ (void)performOnMainThreadSynchronously:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if (NSThread.isMainThread) {
        block();
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), block);
}

+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval {
    if (timeInterval <= 0) {
        return;
    }
    if (!NSThread.isMainThread) {
        [NSThread sleepForTimeInterval:timeInterval];
        return;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    while ([deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

+ (void)waitForMainQueue {
    if (!NSThread.isMainThread) {
        dispatch_sync(dispatch_get_main_queue(), ^{
                          // No work needed; just waiting for the main queue to be idle.
                      });
        return;
    }

    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        drained = YES;
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!drained && [deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end
