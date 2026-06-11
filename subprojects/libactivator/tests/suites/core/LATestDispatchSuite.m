//
//  LATestDispatchSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestDispatchSuite.h"

#import "LATestEnvironment.h"

@implementation LATestDispatchSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"Dispatch"];

    NSString *eventName = @"libactivator.test.dispatch";
    NSString *listenerAName = @"libactivator.test.dispatch.a";
    NSString *listenerBName = @"libactivator.test.dispatch.b";
    NSString *sharedListenerFirstName = @"libactivator.test.dispatch.shared.first";
    NSString *sharedListenerSecondName = @"libactivator.test.dispatch.shared.second";
    NSString *simpleAbortName = @"libactivator.test.dispatch.simple-abort";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *listenerA = [[LATestListener alloc] init];
    LATestListener *listenerB = [[LATestListener alloc] init];
    LATestListener *sharedListener = [[LATestListener alloc] init];
    LATestSimpleAbortListener *simpleAbort = [[LATestSimpleAbortListener alloc] init];
    listenerA.handlesReceivedEvents = YES;

    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:listenerA forName:listenerAName];
    [activator registerListener:listenerB forName:listenerBName];
    [activator registerListener:sharedListener forName:sharedListenerFirstName];
    [activator registerListener:sharedListener forName:sharedListenerSecondName];
    [activator registerListener:(id<LAListener>)simpleAbort forName:simpleAbortName];

    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:event toListenersWithNames:@[ listenerAName, listenerBName ]];
    [activator sendEventToListener:event];
    [recorder expect:event.handled && listenerA.receiveCount == 1 && listenerB.receiveCount == 1
            caseName:@"assigned-dispatch"
              reason:@"Assigned dispatch did not reach expected listeners"];
    [recorder expect:listenerB.otherHandledCount == 1
            caseName:@"other-listener-handled"
              reason:@"Other listener was not notified"];
    [recorder expect:sharedListener.otherHandledCount == 1
            caseName:@"shared-listener-other-handled-once"
              reason:@"Shared listener instance received duplicate handled notifications"];

    LAEvent *explicitEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:explicitEvent toListenersWithNames:@[ listenerBName ]];
    [recorder expect:listenerB.receiveCount == 2 caseName:@"explicit-dispatch" reason:@"Explicit dispatch failed"];

    listenerB.lastReceivedEventMode = LAEventModeSpringBoard;
    [activator sendEvent:[LAEvent eventWithName:eventName] toListenersWithNames:@[ listenerBName ]];
    [recorder expect:listenerB.lastReceivedEventMode == nil
            caseName:@"nil-mode-immediate-dispatch"
              reason:@"Immediate dispatch rewrote nil event mode"];

    listenerB.receiveCount = 0;
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerBName, listenerBName ]];
    [recorder expect:listenerB.receiveCount == 1
            caseName:@"explicit-dispatch-deduplicates-listeners"
              reason:@"Explicit dispatch delivered to a repeated listener name"];

    [activator sendAbortEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
         toListenersWithNames:@[ simpleAbortName ]];
    [recorder expect:simpleAbort.abortCount == 1
            caseName:@"abort-fallback"
              reason:@"Simple abort selector was not used"];

    [activator sendPreviewEventToListenerWithName:listenerAName];
    [recorder expect:listenerA.previewCount == 1 && listenerB.previewCount == 0
            caseName:@"preview-target"
              reason:@"Preview dispatch target mismatch"];

    LAEvent *deactivateEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendDeactivateEventToListeners:deactivateEvent];
    [recorder expect:deactivateEvent.handled && listenerA.deactivateCount == 1 && listenerB.deactivateCount == 1 &&
                     sharedListener.deactivateCount == 1
            caseName:@"deactivate-broadcast"
              reason:@"Deactivate broadcast failed"];
    [activator unregisterListenerWithName:sharedListenerFirstName];
    [activator sendDeactivateEventToListeners:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]];
    [recorder expect:sharedListener.deactivateCount == 2
            caseName:@"shared-listener-kept-after-one-name-removed"
              reason:@"Shared listener instance was removed before its last name"];
    [activator unregisterListenerWithName:sharedListenerSecondName];
    [activator sendDeactivateEventToListeners:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]];
    [recorder expect:sharedListener.deactivateCount == 2
            caseName:@"shared-listener-removed-after-last-name"
              reason:@"Shared listener instance remained after its last name was removed"];

    listenerA.requiresNoTouchEvents = YES;
    listenerA.receiveCount = 0;
    listenerB.receiveCount = 0;
    listenerB.otherHandledCount = 0;
    listenerA.lastReceivedEventMode = LAEventModeSpringBoard;
    LAEvent *deferredEvent = [LAEvent eventWithName:eventName];
    [LATestEnvironment sendSyntheticTouchWithTouching:YES];
    [LATestEnvironment waitForSyntheticTouchDelivery];
    [activator sendEvent:deferredEvent toListenersWithNames:@[ listenerAName, listenerBName ]];
    [recorder expect:deferredEvent.handled && listenerA.receiveCount == 0
            caseName:@"deferred-no-touch-enqueue"
              reason:@"Deferred event was not held while touch was active"];
    [recorder expect:listenerB.receiveCount == 1
            caseName:@"deferred-no-touch-continues-next-listener"
              reason:@"Deferred no-touch dispatch blocked the next listener"];
    [recorder expect:listenerB.otherHandledCount == 1
            caseName:@"deferred-no-touch-notifies-next-listener"
              reason:@"Deferred no-touch dispatch did not notify the next listener"];
    listenerA.compatibleModes = @[];
    [LATestEnvironment sendSyntheticTouchWithTouching:NO];
    [LATestEnvironment waitForSyntheticTouchDelivery];
    [LATestEnvironment waitForMainQueue];
    [recorder expect:listenerA.receiveCount == 1 && listenerB.receiveCount == 1
            caseName:@"deferred-no-touch-drain"
              reason:@"Deferred event did not dispatch after touch ended"];
    [recorder expect:listenerA.receiveCount == 1
            caseName:@"deferred-no-touch-direct-drain"
              reason:@"Deferred event was filtered during drain"];
    [recorder expect:listenerA.lastReceivedEventMode == nil
            caseName:@"nil-mode-deferred-dispatch"
              reason:@"Deferred dispatch rewrote nil event mode"];

    listenerA.compatibleModes = @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
    listenerA.requiresNoTouchEvents = NO;
    listenerA.needsPoweredDisplay = YES;
    listenerA.receiveCount = 0;
    listenerB.receiveCount = 0;
    [activator la_noteScreenBlanked:YES];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerAName, listenerBName ]];
    [recorder expect:listenerA.receiveCount == 0 && listenerB.receiveCount == 1
            caseName:@"needs-powered-display-skips-blank-screen"
              reason:@"Listener requiring powered display ran while the screen was blanked"];
    [activator la_noteScreenBlanked:NO];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerAName ]];
    [recorder expect:listenerA.receiveCount == 1
            caseName:@"needs-powered-display-runs-with-screen-on"
              reason:@"Listener requiring powered display did not run after the screen powered on"];
}

@end
