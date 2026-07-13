//
//  LATestRuntimeDeviceSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRuntimeDeviceSuite.h"

#import "LATestEnvironment.h"
#import "LATestEventDataSource.h"
#import "LATestListener.h"
#import "LATestRecorder.h"
#import "LATweakTestEnvironment.h"

#import <Activator/Activator.h>

@implementation LATestRuntimeDeviceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"RuntimeDevice"];

    NSString *lockedListenerName = @"libactivator.test.device.locked";
    NSString *unlockedListenerName = @"libactivator.test.device.unlocked";

    if ([LATweakTestEnvironment isDeviceLocked]) {
        [LATweakTestEnvironment
            unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""];
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
    }

    if (![LATweakTestEnvironment resetHomeScreen]) {
        [recorder skip:@"home-mode" reason:@"Home automation is unavailable"];
    } else if ([LATweakTestEnvironment isDeviceLocked]) {
        [recorder skip:@"home-mode" reason:@"Device is locked"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.5];
        [LATestEnvironment waitForMainQueue];
        [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeSpringBoard]
                caseName:@"home-mode"
                  reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Home screen did not report springboard mode"
                                                               activator:activator]];

        NSString *preferencesListenerName = @"com.apple.Preferences";
        BOOL preferencesListenerAvailable = [LATestEnvironment
            waitUntilTrue:^BOOL {
                return [activator hasListenerWithName:preferencesListenerName];
            }
                  timeout:5.0];
        [recorder expect:preferencesListenerAvailable
                caseName:@"dynamic-application-preferences-listener-available"
                  reason:@"Preferences dynamic application listener was not registered"];
        if (preferencesListenerAvailable) {
            LAEvent *launchEvent = [LAEvent eventWithName:@"libactivator.test.device.dynamic-app"
                                                     mode:LAEventModeSpringBoard];
            [activator sendEvent:launchEvent toListenerWithName:preferencesListenerName];
            BOOL preferencesFrontMost =
                [LATweakTestEnvironment waitForFrontMostApplicationWithBundleIdentifier:preferencesListenerName
                                                                                timeout:5.0];
            [recorder expect:launchEvent.handled && preferencesFrontMost
                    caseName:@"dynamic-application-preferences-launch"
                      reason:@"Preferences dynamic application listener did not launch Preferences"];
            if ([LATweakTestEnvironment resetHomeScreen]) {
                [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
                [LATestEnvironment waitForMainQueue];
            }
        }
    }

    if (![LATweakTestEnvironment prepareApplicationModeWithBundleIdentifier:@"com.apple.Preferences"
                                                                  activator:activator
                                                                   attempts:3]) {
        [recorder skip:@"application-mode" reason:@"Application launch automation is unavailable"];
    } else {
        [LATestEnvironment waitForMainQueue];
        NSString *frontMost = [LATweakTestEnvironment frontMostDisplayIdentifier];
        [recorder expect:[frontMost isEqualToString:@"com.apple.Preferences"] ||
                         [activator.displayIdentifierForCurrentApplication isEqualToString:@"com.apple.Preferences"]
                caseName:@"application-frontmost"
                  reason:@"Preferences did not become frontmost"];
        [recorder
              expect:[activator.currentEventMode isEqualToString:LAEventModeApplication]
            caseName:@"application-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Foreground app did not report application mode"
                                                           activator:activator]];

        NSString *eventName = @"libactivator.test.dispatch";
        NSString *listenerName = @"libactivator.test.dispatch.a";
        LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
        LATestListener *listener = [[LATestListener alloc] init];
        [activator registerEventDataSource:dataSource forEventName:eventName];
        [activator registerListener:listener forName:listenerName];
        BOOL preferencesWasBlacklisted =
            [activator applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
        [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeApplication]
            toListenersWithNames:@[ listenerName ]];
        [recorder expect:listener.receiveCount == 0
                caseName:@"explicit-dispatch-respects-blacklist"
                  reason:@"Explicit dispatch ignored the foreground application blacklist"];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences"
                                         isBlacklisted:preferencesWasBlacklisted];
    }

    LATestListener *lockedListener = [[LATestListener alloc] init];
    LATestListener *unlockedListener = [[LATestListener alloc] init];
    lockedListener.handlesReceivedEvents = YES;
    unlockedListener.handlesReceivedEvents = YES;
    LAEvent *lockedEvent = [LAEvent eventWithName:LAEventNameDeviceLocked mode:LAEventModeLockScreen];
    LAEvent *springBoardUnlockedEvent = [LAEvent eventWithName:LAEventNameDeviceUnlocked mode:LAEventModeSpringBoard];
    LAEvent *applicationUnlockedEvent = [LAEvent eventWithName:LAEventNameDeviceUnlocked mode:LAEventModeApplication];
    NSString *assignmentProfileName = [activator.currentProfileName copy];
    NSArray<NSString *> *lockedListenerNames = [[activator assignedListenerNamesForEvent:lockedEvent] copy];
    NSArray<NSString *> *springBoardUnlockedListenerNames =
        [[activator assignedListenerNamesForEvent:springBoardUnlockedEvent] copy];
    NSArray<NSString *> *applicationUnlockedListenerNames =
        [[activator assignedListenerNamesForEvent:applicationUnlockedEvent] copy];

    [activator registerListener:lockedListener forName:lockedListenerName];
    [activator registerListener:unlockedListener forName:unlockedListenerName];
    [activator assignEvent:lockedEvent toListenersWithNames:@[ lockedListenerName ]];
    [activator assignEvent:springBoardUnlockedEvent toListenersWithNames:@[ unlockedListenerName ]];
    [activator assignEvent:applicationUnlockedEvent toListenersWithNames:@[ unlockedListenerName ]];

    if (![LATweakTestEnvironment lockDevice]) {
        [recorder skip:@"lockscreen-mode" reason:@"Lock automation is unavailable"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:[LATweakTestEnvironment isDeviceLocked] ||
                         [activator.currentEventMode isEqualToString:LAEventModeLockScreen]
                caseName:@"lockscreen-mode"
                  reason:@"Lock screen did not report lockscreen mode"];
        BOOL receivedLockedEvent = [LATestEnvironment
            waitUntilTrue:^BOOL {
                return lockedListener.receiveCount > 0;
            }
                  timeout:3.0];
        [recorder expect:receivedLockedEvent &&
                         [lockedListener.lastReceivedEventName isEqualToString:LAEventNameDeviceLocked]
                caseName:@"device-locked-event-dispatch"
                  reason:@"Real lock automation did not dispatch the device locked event"];
    }

    if (![LATweakTestEnvironment
            unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""]) {
        [recorder skip:@"unlock-device" reason:@"Unlock automation is unavailable"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:![LATweakTestEnvironment isDeviceLocked]
                caseName:@"unlock-device"
                  reason:@"Device is still locked"];
        BOOL receivedUnlockedEvent = [LATestEnvironment
            waitUntilTrue:^BOOL {
                return unlockedListener.receiveCount > 0;
            }
                  timeout:3.0];
        [recorder expect:receivedUnlockedEvent &&
                         [unlockedListener.lastReceivedEventName isEqualToString:LAEventNameDeviceUnlocked]
                caseName:@"device-unlocked-event-dispatch"
                  reason:@"Real unlock automation did not dispatch the device unlocked event"];
    }
    [activator setCurrentProfileName:assignmentProfileName];
    [activator assignEvent:lockedEvent toListenersWithNames:lockedListenerNames];
    [activator assignEvent:springBoardUnlockedEvent toListenersWithNames:springBoardUnlockedListenerNames];
    [activator assignEvent:applicationUnlockedEvent toListenersWithNames:applicationUnlockedListenerNames];
    [activator unregisterListenerWithName:lockedListenerName];
    [activator unregisterListenerWithName:unlockedListenerName];
    [LATweakTestEnvironment suspendApplication];
}

@end
