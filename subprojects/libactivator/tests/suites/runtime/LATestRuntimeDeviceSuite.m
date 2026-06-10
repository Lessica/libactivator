//
//  LATestRuntimeDeviceSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRuntimeDeviceSuite.h"

#import "LATestEnvironment.h"

@implementation LATestRuntimeDeviceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"RuntimeDevice"];

    if ([LATestEnvironment isDeviceLocked]) {
        [LATestEnvironment unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""];
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
    }

    if (![LATestEnvironment resetHomeScreen]) {
        [recorder skip:@"home-mode" reason:@"Home automation is unavailable"];
    } else if ([LATestEnvironment isDeviceLocked]) {
        [recorder skip:@"home-mode" reason:@"Device is locked"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.5];
        [LATestEnvironment waitForMainQueue];
        [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeSpringBoard]
                caseName:@"home-mode"
                  reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Home screen did not report springboard mode"
                                                  activator:activator]];
    }

    if (![LATestEnvironment prepareApplicationModeWithBundleIdentifier:@"com.apple.Preferences" activator:activator attempts:3]) {
        [recorder skip:@"application-mode" reason:@"Application launch automation is unavailable"];
    } else {
        [LATestEnvironment waitForMainQueue];
        NSString *frontMost = [LATestEnvironment frontMostDisplayIdentifier];
        [recorder expect:[frontMost isEqualToString:@"com.apple.Preferences"] ||
                         [activator.displayIdentifierForCurrentApplication isEqualToString:@"com.apple.Preferences"]
                caseName:@"application-frontmost"
                  reason:@"Preferences did not become frontmost"];
        [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeApplication]
                caseName:@"application-mode"
                  reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Foreground app did not report application mode"
                                                  activator:activator]];

        NSString *eventName = @"libactivator.test.dispatch";
        NSString *listenerName = @"libactivator.test.dispatch.a";
        LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
        LATestListener *listener = [[LATestListener alloc] init];
        [activator registerEventDataSource:dataSource forEventName:eventName];
        [activator registerListener:listener forName:listenerName];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
        [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeApplication]
            toListenersWithNames:@[ listenerName ]];
        [recorder expect:listener.receiveCount == 0
                caseName:@"explicit-dispatch-respects-blacklist"
                  reason:@"Explicit dispatch ignored the foreground application blacklist"];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    }

    if (![LATestEnvironment lockDevice]) {
        [recorder skip:@"lockscreen-mode" reason:@"Lock automation is unavailable"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:[LATestEnvironment isDeviceLocked] || [activator.currentEventMode isEqualToString:LAEventModeLockScreen]
                caseName:@"lockscreen-mode"
                  reason:@"Lock screen did not report lockscreen mode"];
    }

    if (![LATestEnvironment unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""]) {
        [recorder skip:@"unlock-device" reason:@"Unlock automation is unavailable"];
    } else {
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:![LATestEnvironment isDeviceLocked] caseName:@"unlock-device" reason:@"Device is still locked"];
    }

    [LATestEnvironment suspendApplication];
}

@end

