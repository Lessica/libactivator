//
//  LATweakTestEnvironment.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATweakTestEnvironment.h"

#import "LAActivator+Private.h"
#import "LATestEnvironment.h"
#import "LATweakTestPrivateInterfaces.h"

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>

@implementation LATweakTestEnvironment

#pragma mark - Cleanup

+ (void)cleanActivator:(LAActivator *)activator {
    NSArray<NSString *> *listenerNames = @[
        @"libactivator.test.device.locked",
        @"libactivator.test.device.unlocked",
        @"libactivator.test.event-source-registry.listener",
        @"libactivator.test.event-source-registry.network-specific",
        @"libactivator.test.event-source-registry.network-base",
        @"libactivator.test.event-definition-registry.network-specific",
        @"libactivator.test.event-definition-registry.network-base",
        @"libactivator.test.url.missing",
        @"libactivator.test.url.invalid",
    ];
    NSArray<NSString *> *eventNames = @[
        @"libactivator.test.built-in.nothing",
        @"libactivator.test.built-in.url",
        @"libactivator.test.event-source-registry.shared",
        @"libactivator.test.event-source-registry.secondary",
        @"libactivator.test.event-source-registry.dynamic-a",
        @"libactivator.test.event-source-registry.dynamic-b",
        @"libactivator.test.event-source-registry.foreign",
        @"libactivator.test.event-source-registry.preowned",
        @"libactivator.network.joined-wifi.libactivator-test-registry",
        @"libactivator.test.event-definition-registry.a",
        @"libactivator.test.event-definition-registry.b",
        @"libactivator.test.event-definition-registry.c",
        @"libactivator.test.event-definition-registry.d",
        @"libactivator.test.event-definition-registry.e",
        @"libactivator.test.event-definition-registry.preowned",
        @"libactivator.test.event-definition-registry.unregister-reentrant",
        @"libactivator.test.event-definition-registry.inactive-a",
        @"libactivator.test.event-definition-registry.inactive-b",
    ];

    NSDictionary<NSString *, NSArray<NSString *> *> *productionEventListenerNames = @{
        LAEventNameDeviceLocked : @[ @"libactivator.test.device.locked" ],
        LAEventNameDeviceUnlocked : @[ @"libactivator.test.device.unlocked" ],
        LAEventNameNetworkJoinedWiFi : @[
            @"libactivator.test.event-definition-registry.network-base",
            @"libactivator.test.event-source-registry.network-base",
        ],
    };
    for (NSString *eventName in eventNames) {
        [activator la_unassignEventNameFromAllProfilesAndNotifyIfChanged:eventName];
    }

    NSString *previousProfileName = [activator.currentProfileName copy] ?: @"Default";
    NSMutableOrderedSet<NSString *> *profileNames =
        [NSMutableOrderedSet orderedSetWithArray:activator.availableProfileNames ?: @[]];
    [profileNames addObject:previousProfileName];
    for (NSString *profileName in profileNames) {
        [activator setCurrentProfileName:profileName];
        [productionEventListenerNames
            enumerateKeysAndObjectsUsingBlock:^(NSString *eventName, NSArray<NSString *> *assignedListenerNames,
                                                __unused BOOL *stop) {
                for (NSString *mode in activator.availableEventModes) {
                    LAEvent *event = [LAEvent eventWithName:eventName mode:mode];
                    for (NSString *listenerName in assignedListenerNames) {
                        [activator removeListenerAssignment:listenerName fromEvent:event];
                    }
                }
            }];
    }
    [activator setCurrentProfileName:previousProfileName];

    for (NSString *eventName in eventNames) {
        [activator unregisterEventDataSourceWithEventName:eventName];
    }
    for (NSString *listenerName in listenerNames) {
        [activator unregisterListenerWithName:listenerName];
    }
}

#pragma mark - Device Automation

+ (BOOL)resetHomeScreen {
    __block BOOL attempted = NO;
    [LATestEnvironment performOnMainThreadSynchronously:^{
        Class automationClass = NSClassFromString(@"SBSTestAutomationService");
        SBSTestAutomationService *service = automationClass ? [[automationClass alloc] init] : nil;
        if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)]) {
            [service resetToHomeScreenAnimated:NO useSafeTransitions:YES];
            attempted = YES;
        } else if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:)]) {
            [service resetToHomeScreenAnimated:NO];
            attempted = YES;
        } else {
            Class springBoardClass = NSClassFromString(@"SpringBoard");
            SpringBoard *springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                                           ? [springBoardClass sharedApplication]
                                           : (SpringBoard *)UIApplication.sharedApplication;
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
    [LATestEnvironment performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        SpringBoard *springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                                       ? [springBoardClass sharedApplication]
                                       : (SpringBoard *)UIApplication.sharedApplication;
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
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.75];
        [LATestEnvironment waitForMainQueue];
        if ([activator.currentEventMode isEqualToString:LAEventModeApplication] &&
            [activator.displayIdentifierForCurrentApplication isEqualToString:bundleIdentifier]) {
            return YES;
        }
        if (attempt + 1 < effectiveAttempts && [self resetHomeScreen]) {
            [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
            [LATestEnvironment waitForMainQueue];
        }
    }
    return openedAtLeastOnce;
}

+ (BOOL)suspendApplication {
    __block BOOL attempted = NO;
    [LATestEnvironment performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        SpringBoard *springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                                       ? [springBoardClass sharedApplication]
                                       : (SpringBoard *)UIApplication.sharedApplication;
        if ([springBoard respondsToSelector:@selector(suspend)]) {
            [springBoard suspend];
            attempted = YES;
        }
    }];
    return attempted;
}

+ (BOOL)lockDevice {
    __block BOOL attempted = NO;
    [LATestEnvironment performOnMainThreadSynchronously:^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        SBLockScreenManager *manager =
            [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(remoteLock:)]) {
            [manager remoteLock:YES];
            attempted = YES;
            Class backlightClass = NSClassFromString(@"SBBacklightController");
            SBBacklightController *backlight =
                [backlightClass respondsToSelector:@selector(sharedInstance)] ? [backlightClass sharedInstance] : nil;
            if ([backlight respondsToSelector:@selector(_startFadeOutAnimationFromLockSource:)]) {
                [backlight _startFadeOutAnimationFromLockSource:1];
            }
        }
    }];
    return attempted;
}

+ (BOOL)unlockDeviceWithPasscode:(NSString *)passcode {
    __block BOOL attempted = NO;
    NSString *passcodeToUse = [passcode copy] ?: @"";
    [LATestEnvironment performOnMainThreadSynchronously:^{
        attempted = [self attemptUnlockOnMainThreadWithPasscode:passcodeToUse fallbackToHomeScreen:YES];
    }];
    return attempted;
}

+ (BOOL)attemptUnlockOnMainThreadWithPasscode:(NSString *)passcode fallbackToHomeScreen:(BOOL)fallbackToHomeScreen {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    SBLockScreenManager *manager =
        [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @"" finishUIUnlock:YES completion:nil];
        return YES;
    }
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @""];
        return YES;
    }
    return fallbackToHomeScreen ? [self resetHomeScreen] : NO;
}

+ (BOOL)isDeviceLocked {
    __block BOOL locked = NO;
    [LATestEnvironment performOnMainThreadSynchronously:^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        SBLockScreenManager *manager =
            [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(isUILocked)]) {
            locked = [manager isUILocked];
        }
    }];
    return locked;
}

+ (NSString *)frontMostDisplayIdentifier {
    __block NSString *displayIdentifier = nil;
    [LATestEnvironment performOnMainThreadSynchronously:^{
        UIApplication *application = UIApplication.sharedApplication;
        if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
            return;
        }

        SBApplication *frontMostApplication = [application _accessibilityFrontMostApplication];
        if ([frontMostApplication respondsToSelector:@selector(bundleIdentifier)]) {
            displayIdentifier = [frontMostApplication bundleIdentifier];
        }
        if (displayIdentifier.length == 0 && [frontMostApplication respondsToSelector:@selector(displayIdentifier)]) {
            displayIdentifier = [frontMostApplication displayIdentifier];
        }
    }];
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
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    }
    return [[self frontMostDisplayIdentifier] isEqualToString:bundleIdentifier];
}

@end
