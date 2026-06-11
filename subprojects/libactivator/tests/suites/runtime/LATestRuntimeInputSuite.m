//
//  LATestRuntimeInputSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRuntimeInputSuite.h"

#import "LATestEnvironment.h"

@implementation LATestRuntimeInputSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"RuntimeInput"];

    [LATestEnvironment cleanRuntimeInputStateWithActivator:activator];
    [activator la_updateRuntimeEventMode:LAEventModeApplication
                    underneathLockScreen:LAEventModeApplication
                       displayIdentifier:@"com.apple.Preferences"
                                screenOn:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeApplication]
            caseName:@"foreground-app-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Foreground app did not report application mode"
                                                           activator:activator]];
    [recorder expect:[activator.displayIdentifierForCurrentApplication isEqualToString:@"com.apple.Preferences"]
            caseName:@"foreground-app-display-identifier"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Foreground app display identifier was not cached"
                                                           activator:activator]];

    [activator la_updateRuntimeEventMode:LAEventModeLockScreen
                    underneathLockScreen:LAEventModeApplication
                       displayIdentifier:nil
                                screenOn:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeLockScreen] &&
                     [activator.currentEventModeUnderneathLockScreen isEqualToString:LAEventModeApplication]
            caseName:@"ui-locked-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"UI lock state did not report lockscreen mode"
                                                           activator:activator]];
    [activator la_updateRuntimeEventMode:LAEventModeApplication
                    underneathLockScreen:LAEventModeApplication
                       displayIdentifier:@"com.apple.Preferences"
                                screenOn:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeApplication]
            caseName:@"ui-unlocked-underneath-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"UI unlock state did not restore underneath mode"
                                                           activator:activator]];

    [activator la_updateRuntimeEventMode:LAEventModeSpringBoard
                    underneathLockScreen:LAEventModeSpringBoard
                       displayIdentifier:nil
                                screenOn:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeSpringBoard] &&
                     activator.displayIdentifierForCurrentApplication == nil
            caseName:@"foreground-app-clear"
              reason:[LATestEnvironment
                         runtimeDebugReasonWithPrefix:@"Cleared foreground app did not restore SpringBoard mode"
                                            activator:activator]];

    [activator la_updateRuntimeEventMode:LAEventModeLockScreen
                    underneathLockScreen:LAEventModeSpringBoard
                       displayIdentifier:nil
                                screenOn:NO];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeLockScreen]
            caseName:@"screen-blanked-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Blank screen did not report lockscreen mode"
                                                           activator:activator]];
    [activator la_updateRuntimeEventMode:LAEventModeSpringBoard
                    underneathLockScreen:LAEventModeSpringBoard
                       displayIdentifier:nil
                                screenOn:YES];

    NSString *eventName = @"libactivator.test.dispatch";
    NSString *unlockingListenerName = @"libactivator.test.dispatch.unlock";
    NSString *lockScreenListenerName = @"libactivator.test.dispatch.lock";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *unlockingListener = [[LATestListener alloc] init];
    LATestListener *lockScreenListener = [[LATestListener alloc] init];
    unlockingListener.compatibleModes = @[ LAEventModeSpringBoard ];
    lockScreenListener.compatibleModes = @[ LAEventModeLockScreen ];
    dataSource.supportsUnlockingDeviceToSend = YES;
    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:unlockingListener forName:unlockingListenerName];
    [activator registerListener:lockScreenListener forName:lockScreenListenerName];
    [activator la_updateRuntimeEventMode:LAEventModeLockScreen
                    underneathLockScreen:LAEventModeSpringBoard
                       displayIdentifier:nil
                                screenOn:YES];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeLockScreen]
        toListenersWithNames:@[ unlockingListenerName, lockScreenListenerName ]];
    [recorder expect:unlockingListener.unlockingCount == 1
            caseName:@"unlock-to-send-callback"
              reason:@"Unlock-to-send callback did not run"];
    [recorder expect:lockScreenListener.receiveCount == 0
            caseName:@"unlock-to-send-stops-normal-dispatch"
              reason:@"Lock screen listener received an event after unlock-to-send handled it"];

    [LATestEnvironment cleanRuntimeInputStateWithActivator:activator];
}

@end
