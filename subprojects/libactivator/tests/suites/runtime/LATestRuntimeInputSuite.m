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
    [activator la_noteHomeScreenVisible:YES source:@"test.home.a"];
    [activator la_noteHomeScreenVisible:YES source:@"test.home.b"];
    NSDictionary *homeAddedState = [activator la_runtimeStateDebugDictionary];
    NSArray *homeAddedSources = homeAddedState[@"HomeSources"];
    [recorder
          expect:[homeAddedSources containsObject:@"test.home.a"] && [homeAddedSources containsObject:@"test.home.b"]
        caseName:@"home-source-add"
          reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Home sources were not tracked" activator:activator]];

    [activator la_noteHomeScreenVisible:NO source:@"test.home.a"];
    NSDictionary *homeRemovedState = [activator la_runtimeStateDebugDictionary];
    NSArray *homeRemovedSources = homeRemovedState[@"HomeSources"];
    [recorder expect:![homeRemovedSources containsObject:@"test.home.a"] &&
                     [homeRemovedSources containsObject:@"test.home.b"]
            caseName:@"home-source-remove"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Home source removal failed" activator:activator]];

    [activator la_noteHomeScreenVisible:NO];
    NSDictionary *homeClearedState = [activator la_runtimeStateDebugDictionary];
    [recorder expect:[homeClearedState[@"HomeSources"] count] == 0
            caseName:@"home-source-clear"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Home source clear failed" activator:activator]];

    [activator la_noteLockScreenVisible:YES source:@"test.lock.a"];
    [activator la_noteLockScreenVisible:YES source:@"test.lock.b"];
    NSDictionary *lockAddedState = [activator la_runtimeStateDebugDictionary];
    NSArray *lockAddedSources = lockAddedState[@"LockSources"];
    [recorder
          expect:[lockAddedSources containsObject:@"test.lock.a"] && [lockAddedSources containsObject:@"test.lock.b"]
        caseName:@"lock-source-add"
          reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Lock sources were not tracked" activator:activator]];

    [activator la_noteLockScreenVisible:NO source:@"test.lock.a"];
    NSDictionary *lockRemovedState = [activator la_runtimeStateDebugDictionary];
    NSArray *lockRemovedSources = lockRemovedState[@"LockSources"];
    [recorder expect:![lockRemovedSources containsObject:@"test.lock.a"] &&
                     [lockRemovedSources containsObject:@"test.lock.b"]
            caseName:@"lock-source-remove"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Lock source removal failed" activator:activator]];

    [activator la_noteLockScreenVisible:NO];
    NSDictionary *lockClearedState = [activator la_runtimeStateDebugDictionary];
    [recorder expect:[lockClearedState[@"LockSources"] count] == 0
            caseName:@"lock-source-clear"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Lock source clear failed" activator:activator]];

    [activator la_noteScreenBlanked:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeLockScreen]
            caseName:@"screen-blanked-mode"
              reason:[LATestEnvironment runtimeDebugReasonWithPrefix:@"Blank screen did not report lockscreen mode"
                                              activator:activator]];
    [activator la_noteScreenBlanked:NO];
    [activator la_noteRuntimeStateMayHaveChanged];

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
    [activator la_noteHomeScreenVisible:YES];
    [activator la_noteLockScreenVisible:YES];
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

