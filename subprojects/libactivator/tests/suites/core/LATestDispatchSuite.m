//
//  LATestDispatchSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestDispatchSuite.h"

#import "LAActivator+Private.h"
#import "LARuntimeContext.h"
#import "LATestEnvironment.h"
#import "LATestEventDataSource.h"
#import "LATestListener.h"
#import "LATestRecorder.h"
#import "LATestSimpleAbortListener.h"

#import <Activator/Activator.h>

@interface LARuntimeContext (LATestDispatch)

@property(nonatomic, copy, nullable, readonly) BOOL (^touchActiveProvider)(void);
@property(nonatomic, copy, nullable, readonly) void (^touchesEndedPerformer)(dispatch_block_t block);

@end

@implementation LATestDispatchSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"Dispatch"];

    NSDictionary<NSString *, id> *runtimeInputState =
        [LATestEnvironment runtimeInputStateSnapshotWithActivator:activator];
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
    [activator la_resetDispatchCounts];
    [recorder expect:activator.la_eventDispatchCounts.count == 0 && activator.la_listenerReceiveCounts.count == 0 &&
                     activator.la_eventAbortCounts.count == 0 && activator.la_listenerAbortCounts.count == 0
            caseName:@"dispatch-counts-reset"
              reason:@"Dispatch counts were not reset"];
    [activator sendEventToListener:event];
    [recorder expect:event.handled && listenerA.receiveCount == 1 && listenerB.receiveCount == 1
            caseName:@"assigned-dispatch"
              reason:@"Assigned dispatch did not reach expected listeners"];
    NSDictionary<NSString *, NSNumber *> *eventDispatchCounts = [activator la_eventDispatchCounts];
    NSDictionary<NSString *, NSNumber *> *listenerReceiveCounts = [activator la_listenerReceiveCounts];
    [recorder expect:[eventDispatchCounts[eventName] unsignedLongLongValue] == 1
            caseName:@"event-dispatch-count"
              reason:@"Event dispatch count did not increment once"];
    [recorder expect:[listenerReceiveCounts[listenerAName] unsignedLongLongValue] == 1 &&
                     [listenerReceiveCounts[listenerBName] unsignedLongLongValue] == 1
            caseName:@"listener-receive-count"
              reason:@"Listener receive counts did not increment once per delivered listener"];
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

    NSMutableString *mutableListenerAName = [listenerAName mutableCopy];
    NSMutableArray<NSString *> *mutableListenerNames =
        [@[ mutableListenerAName, [mutableListenerAName copy], listenerBName ] mutableCopy];
    NSInteger listenerAReceiveCount = listenerA.receiveCount;
    NSInteger listenerBReceiveCount = listenerB.receiveCount;
    listenerA.receiveHandler = ^{
        [mutableListenerNames removeAllObjects];
        [mutableListenerAName appendString:@".changed"];
    };
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:mutableListenerNames];
    [recorder expect:mutableListenerNames.count == 0 && listenerA.receiveCount == listenerAReceiveCount + 1 &&
                     listenerB.receiveCount == listenerBReceiveCount + 1
            caseName:@"dispatch-snapshots-listener-name-array"
              reason:@"Reentrant mutation of the caller's listener array disrupted dispatch"];

    LATestListener *metadataReplacementListenerB = [[LATestListener alloc] init];
    listenerBReceiveCount = listenerB.receiveCount;
    listenerB.metadataHandler = ^{
        [activator registerListener:metadataReplacementListenerB forName:listenerBName];
    };
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerBName ]];
    [recorder expect:listenerB.receiveCount == listenerBReceiveCount && metadataReplacementListenerB.receiveCount == 0
            caseName:@"dispatch-revalidates-owner-after-metadata"
              reason:@"Dispatch delivered after listener ownership changed during metadata lookup"];
    listenerB.metadataHandler = nil;
    [activator registerListener:listenerB forName:listenerBName];

    LATestListener *replacementListenerB = [[LATestListener alloc] init];
    replacementListenerB.compatibleModes = @[ LAEventModeApplication ];
    listenerBReceiveCount = listenerB.receiveCount;
    listenerA.receiveHandler = ^{
        [activator registerListener:replacementListenerB forName:listenerBName];
    };
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerAName, listenerBName ]];
    [recorder expect:listenerB.receiveCount == listenerBReceiveCount && replacementListenerB.receiveCount == 0
            caseName:@"dispatch-revalidates-replaced-listener"
              reason:@"Dispatch delivered to a listener owner that changed after preflight"];
    listenerA.receiveHandler = nil;
    [activator registerListener:listenerB forName:listenerBName];

    [activator sendAbortEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
         toListenersWithNames:@[ simpleAbortName ]];
    [recorder expect:simpleAbort.abortCount == 1
            caseName:@"abort-fallback"
              reason:@"Simple abort selector was not used"];
    NSDictionary<NSString *, NSNumber *> *eventAbortCounts = [activator la_eventAbortCounts];
    NSDictionary<NSString *, NSNumber *> *listenerAbortCounts = [activator la_listenerAbortCounts];
    [recorder expect:[eventAbortCounts[eventName] unsignedLongLongValue] == 1
            caseName:@"event-abort-count"
              reason:@"Event abort count did not increment once"];
    [recorder expect:[listenerAbortCounts[simpleAbortName] unsignedLongLongValue] == 1
            caseName:@"listener-abort-count"
              reason:@"Listener abort count did not increment once"];

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
    LARuntimeContext *runtimeContext = [LATestEnvironment runtimeContextForActivator:activator];
    BOOL (^previousTouchActiveProvider)(void) = [runtimeContext.touchActiveProvider copy];
    void (^previousTouchesEndedPerformer)(dispatch_block_t block) = [runtimeContext.touchesEndedPerformer copy];
    __block BOOL touchActive = YES;
    __block dispatch_block_t pendingTouchesEndedBlock = nil;
    [runtimeContext
        setTouchActivityProvider:^BOOL {
            return touchActive;
        }
        touchesEndedPerformer:^(dispatch_block_t block) {
            pendingTouchesEndedBlock = [block copy];
        }];
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
    listenerA.compatibleModes = @[ LAEventModeApplication ];
    touchActive = NO;
    dispatch_block_t touchesEndedBlock = pendingTouchesEndedBlock;
    pendingTouchesEndedBlock = nil;
    if (touchesEndedBlock) {
        dispatch_async(dispatch_get_main_queue(), touchesEndedBlock);
    }
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
    touchActive = YES;
    [activator sendEvent:[LAEvent eventWithName:eventName] toListenersWithNames:@[ listenerAName ]];
    LATestListener *deferredReplacementListener = [[LATestListener alloc] init];
    deferredReplacementListener.compatibleModes = @[ LAEventModeApplication ];
    [activator registerListener:deferredReplacementListener forName:listenerAName];
    touchActive = NO;
    touchesEndedBlock = pendingTouchesEndedBlock;
    pendingTouchesEndedBlock = nil;
    if (touchesEndedBlock) {
        dispatch_async(dispatch_get_main_queue(), touchesEndedBlock);
    }
    [LATestEnvironment waitForMainQueue];
    [recorder expect:listenerA.receiveCount == 1 && deferredReplacementListener.receiveCount == 1
            caseName:@"deferred-no-touch-resolves-current-name-owner"
              reason:@"Deferred dispatch retained a stale listener owner instead of the listener name"];
    [activator registerListener:listenerA forName:listenerAName];
    [runtimeContext setTouchActivityProvider:previousTouchActiveProvider
                       touchesEndedPerformer:previousTouchesEndedPerformer];

    listenerA.requiresNoTouchEvents = NO;
    listenerA.needsPoweredDisplay = YES;
    listenerA.receiveCount = 0;
    listenerB.receiveCount = 0;
    [[LATestEnvironment runtimeContextForActivator:activator] updateEventMode:LAEventModeLockScreen
                                                         underneathLockScreen:LAEventModeSpringBoard
                                                            displayIdentifier:nil
                                                                     screenOn:NO];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerAName, listenerBName ]];
    [recorder expect:listenerA.receiveCount == 0 && listenerB.receiveCount == 1
            caseName:@"needs-powered-display-skips-blank-screen"
              reason:@"Listener requiring powered display ran while the screen was blanked"];
    [[LATestEnvironment runtimeContextForActivator:activator] updateEventMode:LAEventModeSpringBoard
                                                         underneathLockScreen:LAEventModeSpringBoard
                                                            displayIdentifier:nil
                                                                     screenOn:YES];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerAName ]];
    [recorder expect:listenerA.receiveCount == 1
            caseName:@"needs-powered-display-runs-with-screen-on"
              reason:@"Listener requiring powered display did not run after the screen powered on"];
    [activator la_resetDispatchCounts];
    [LATestEnvironment restoreRuntimeInputStateSnapshot:runtimeInputState activator:activator];
}

@end
