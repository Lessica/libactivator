//
//  LATestEventSourceAcquisitionSuite.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSourceAcquisitionSuite.h"

#import "LAActivator+Private.h"
#import "LATButtonEventSource.h"
#import "LATEdgeGestureEventSource.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATForceTouchEventSource.h"
#import "LATGestureBarEventSource.h"
#import "LATLockScreenClockEventSource.h"
#import "LATMotionEventSource.h"
#import "LATMultiTouchEventSource.h"
#import "LATSpringBoardIconGestureEventSource.h"
#import "LATStatusBarEventSource.h"
#import "LATVolumeHUDTapEventSource.h"
#import "LATestEnvironment.h"
#import "LATestEventSourceFixture.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>

@interface LATestHeadsetButtonEventRuntime
    : NSObject <LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying>

@property(nonatomic, assign) BOOL holdAssigned;
@property(nonatomic, assign) BOOL handlesHold;
@property(nonatomic, assign) NSUInteger deactivateCount;

- (NSUInteger)dispatchCountForEventName:(NSString *)eventName;

@end

@implementation LATestHeadsetButtonEventRuntime {
    NSMutableDictionary<NSString *, NSNumber *> *_dispatchCounts;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatchCounts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dispatchEvent:(LAEvent *)event {
    _dispatchCounts[event.name] = @([_dispatchCounts[event.name] unsignedIntegerValue] + 1);
    if (self.handlesHold && [event.name isEqualToString:LAEventNameHeadsetButtonHoldShort]) {
        event.handled = YES;
    }
}

- (void)abortEvent:(__unused LAEvent *)event {
}

- (void)deactivateEvent:(__unused LAEvent *)event {
    self.deactivateCount += 1;
}

- (NSString *)currentEventMode {
    return LAEventModeSpringBoard;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    return LAEventModeSpringBoard;
}

- (BOOL)hasAssignedListenerForEvent:(LAEvent *)event {
    return self.holdAssigned && [event.name isEqualToString:LAEventNameHeadsetButtonHoldShort];
}

- (NSUInteger)dispatchCountForEventName:(NSString *)eventName {
    return [_dispatchCounts[eventName] unsignedIntegerValue];
}

@end

@implementation LATestEventSourceAcquisitionSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"EventSourceAcquisition"];

    [self runInterestCleanupTestsWithRecorder:recorder activator:activator];
    [self runHeadsetButtonEventSourceTestsWithRecorder:recorder activator:activator];
    [self runStatusBarEventSourceTestsWithRecorder:recorder activator:activator];
    [self runSpringBoardIconGestureEventSourceTestsWithRecorder:recorder activator:activator];
    [self runMotionEventSourceTestsWithRecorder:recorder activator:activator];
    [self runVolumeHUDTapEventSourceTestsWithRecorder:recorder activator:activator];
    [self runGestureBarEventSourceTestsWithRecorder:recorder activator:activator];
    [self runLockScreenClockEventSourceTestsWithRecorder:recorder activator:activator];
    [self runFingerprintSensorEventSourceTestsWithRecorder:recorder activator:activator];
    [self runEdgeGestureEventSourceDispatchTestsWithRecorder:recorder activator:activator];
    [self runForceTouchEventSourceTestsWithRecorder:recorder activator:activator];
    [self runMultiTouchEventSourceDispatchTestsWithRecorder:recorder activator:activator];
}

+ (void)runHeadsetButtonEventSourceTestsWithRecorder:(LATestRecorder *)recorder
                                           activator:(__unused LAActivator *)activator {
    LATestHeadsetButtonEventRuntime *notStartedRuntime = [[LATestHeadsetButtonEventRuntime alloc] init];
    LATButtonEventSource *notStartedSource = [[LATButtonEventSource alloc] initWithEventDispatcher:notStartedRuntime
                                                                                      modeProvider:notStartedRuntime
                                                                                assignmentQuerying:notStartedRuntime];
    [notStartedSource la_testingNoteHeadsetButtonDown:YES];
    [notStartedSource la_testingNoteHeadsetButtonDown:NO];
    [recorder expect:[notStartedRuntime dispatchCountForEventName:LAEventNameHeadsetButtonPressSingle] == 0 &&
                     [notStartedRuntime dispatchCountForEventName:LAEventNameHeadsetButtonHoldShort] == 0
            caseName:@"headset-button-ignores-events-before-start"
              reason:@"Headset button source dispatched before it was started"];

    LATestHeadsetButtonEventRuntime *singlePressRuntime = [[LATestHeadsetButtonEventRuntime alloc] init];
    LATButtonEventSource *singlePressSource = [[LATButtonEventSource alloc] initWithEventDispatcher:singlePressRuntime
                                                                                       modeProvider:singlePressRuntime
                                                                                 assignmentQuerying:singlePressRuntime];
    [singlePressSource start];
    [singlePressSource la_testingNoteHeadsetButtonDown:YES];
    BOOL scheduledWithoutAssignment = [singlePressSource la_testingIsHeadsetHoldRecognitionScheduled];
    [singlePressSource la_testingNoteHeadsetButtonDown:NO];
    [recorder expect:!scheduledWithoutAssignment && singlePressRuntime.deactivateCount == 1 &&
                     [singlePressRuntime dispatchCountForEventName:LAEventNameHeadsetButtonPressSingle] == 1 &&
                     [singlePressRuntime dispatchCountForEventName:LAEventNameHeadsetButtonHoldShort] == 0
            caseName:@"headset-button-dispatches-single-without-hold-assignment"
              reason:@"Headset button source scheduled an unassigned hold or failed to dispatch the single press"];

    LATestHeadsetButtonEventRuntime *handledHoldRuntime = [[LATestHeadsetButtonEventRuntime alloc] init];
    handledHoldRuntime.holdAssigned = YES;
    handledHoldRuntime.handlesHold = YES;
    LATButtonEventSource *handledHoldSource = [[LATButtonEventSource alloc] initWithEventDispatcher:handledHoldRuntime
                                                                                       modeProvider:handledHoldRuntime
                                                                                 assignmentQuerying:handledHoldRuntime];
    [handledHoldSource start];
    [handledHoldSource la_testingNoteHeadsetButtonDown:YES];
    [handledHoldSource la_testingNoteHeadsetButtonDown:YES];
    BOOL scheduledWithAssignment = [handledHoldSource la_testingIsHeadsetHoldRecognitionScheduled];
    [handledHoldSource la_testingResolveHeadsetHold];
    [handledHoldSource la_testingResolveHeadsetHold];
    [handledHoldSource la_testingNoteHeadsetButtonDown:NO];
    [handledHoldSource la_testingNoteHeadsetButtonDown:NO];
    [recorder
          expect:scheduledWithAssignment && handledHoldRuntime.deactivateCount == 0 &&
                 [handledHoldRuntime dispatchCountForEventName:LAEventNameHeadsetButtonHoldShort] == 1 &&
                 [handledHoldRuntime dispatchCountForEventName:LAEventNameHeadsetButtonPressSingle] == 0
        caseName:@"headset-button-handled-hold-suppresses-single"
          reason:@"Headset button source did not deduplicate the hold or leaked a single press after it was handled"];

    LATestHeadsetButtonEventRuntime *unhandledHoldRuntime = [[LATestHeadsetButtonEventRuntime alloc] init];
    unhandledHoldRuntime.holdAssigned = YES;
    LATButtonEventSource *unhandledHoldSource =
        [[LATButtonEventSource alloc] initWithEventDispatcher:unhandledHoldRuntime
                                                 modeProvider:unhandledHoldRuntime
                                           assignmentQuerying:unhandledHoldRuntime];
    [unhandledHoldSource start];
    [unhandledHoldSource la_testingNoteHeadsetButtonDown:YES];
    [unhandledHoldSource la_testingResolveHeadsetHold];
    [unhandledHoldSource la_testingNoteHeadsetButtonDown:NO];
    [recorder expect:unhandledHoldRuntime.deactivateCount == 1 &&
                     [unhandledHoldRuntime dispatchCountForEventName:LAEventNameHeadsetButtonHoldShort] == 1 &&
                     [unhandledHoldRuntime dispatchCountForEventName:LAEventNameHeadsetButtonPressSingle] == 1
            caseName:@"headset-button-unhandled-hold-falls-back-to-single"
              reason:@"Headset button source suppressed the single press after an unhandled hold"];

    LATestHeadsetButtonEventRuntime *invalidatedRuntime = [[LATestHeadsetButtonEventRuntime alloc] init];
    invalidatedRuntime.holdAssigned = YES;
    LATButtonEventSource *invalidatedSource = [[LATButtonEventSource alloc] initWithEventDispatcher:invalidatedRuntime
                                                                                       modeProvider:invalidatedRuntime
                                                                                 assignmentQuerying:invalidatedRuntime];
    [invalidatedSource start];
    [invalidatedSource la_testingNoteHeadsetButtonDown:YES];
    BOOL scheduledBeforeInvalidation = [invalidatedSource la_testingIsHeadsetHoldRecognitionScheduled];
    [invalidatedSource invalidate];
    [invalidatedSource la_testingResolveHeadsetHold];
    [invalidatedSource la_testingNoteHeadsetButtonDown:NO];
    [recorder expect:scheduledBeforeInvalidation && ![invalidatedSource la_testingIsHeadsetHoldRecognitionScheduled] &&
                     [invalidatedRuntime dispatchCountForEventName:LAEventNameHeadsetButtonHoldShort] == 0 &&
                     [invalidatedRuntime dispatchCountForEventName:LAEventNameHeadsetButtonPressSingle] == 0
            caseName:@"headset-button-invalidation-cancels-pending-hold"
              reason:@"Headset button source retained or dispatched recognition state after invalidation"];
}

+ (void)runInterestCleanupTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);
    LATEdgeGestureEventSource *edgeSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    LATForceTouchEventSource *forceSource =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    LATMultiTouchEventSource *multiTouchSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    LATSpringBoardIconGestureEventSource *springBoardIconSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    LATStatusBarEventSource *statusBarSource =
        [fixture interestedEventSourceOfClass:LATStatusBarEventSource.class previousEventSources:@[]];

    [edgeSource start];
    [edgeSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                    [self edgeGesturePointWithX:200.0 y:798.0],
                ]
                                                                               phase:0]
                                      bounds:bounds
                                   timestamp:0.0];
    [edgeSource eventSourceInterestDidChange:NO];
    NSString *eventName = [edgeSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                          [self edgeGesturePointWithX:200.0 y:700.0],
                                      ]
                                                                                                     phase:1]
                                                            bounds:bounds
                                                         timestamp:0.1];
    [recorder expect:eventName == nil
            caseName:@"edge-interest-change-resets-classifier"
              reason:@"Edge source kept classifier state after losing interest"];

    if (forceSource) {
        [forceSource start];
        [forceSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
        ]
                                           bounds:bounds
                                        timestamp:0.0];
        [forceSource eventSourceInterestDidChange:NO];
        [recorder expect:![forceSource la_testingHasRecognitionState]
                caseName:@"force-touch-interest-change-resets-state"
                  reason:@"Force touch source kept recognition state after losing interest"];
    } else {
        [recorder skip:@"force-touch-interest-change-resets-state"
                reason:@"Force touch metadata is not available on this device"];
    }

    [multiTouchSource start];
    [multiTouchSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                                   phase:UITouchPhaseBegan
                                                  bounds:bounds
                                               timestamp:0.0];
    [multiTouchSource eventSourceInterestDidChange:NO];
    [recorder expect:![multiTouchSource la_testingHasRecognitionState]
            caseName:@"multi-touch-interest-change-resets-state"
              reason:@"Multi-touch source kept recognition state after losing interest"];

    [springBoardIconSource start];
    [activator la_resetDispatchCounts];
    [springBoardIconSource la_testingHandlePinchScale:1.0 state:UIGestureRecognizerStateBegan bounds:bounds];
    [springBoardIconSource eventSourceInterestDidChange:NO];
    [recorder expect:![springBoardIconSource la_testingHasRecognitionState] &&
                     [fixture dispatchCountForEventName:LAEventNameSpringBoardPinch] == 0
            caseName:@"springboard-icon-interest-change-resets-pinch-state"
              reason:@"SpringBoard icon source kept pinch state after losing interest"];

    [statusBarSource start];
    [activator la_resetDispatchCounts];
    NSObject *view = [[NSObject alloc] init];
    CGRect statusBarBounds = CGRectMake(0.0, 0.0, 400.0, 40.0);
    [statusBarSource la_testingNoteTouchBeganInStatusBarView:view
                                                      bounds:statusBarBounds
                                                    location:CGPointMake(200.0, 10.0)
                                                    tapCount:1];
    [statusBarSource eventSourceInterestDidChange:NO];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.6];
    [recorder expect:![statusBarSource la_testingHasSessionForStatusBarView:view] &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarHold] == 0
            caseName:@"status-bar-interest-change-cancels-session"
              reason:@"Status bar source kept a session or timer after losing interest"];

    [statusBarSource invalidate];
    [springBoardIconSource invalidate];
    [multiTouchSource invalidate];
    [forceSource invalidate];
    [edgeSource invalidate];
}

+ (void)runStatusBarEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATStatusBarEventSource *source =
        [fixture interestedEventSourceOfClass:LATStatusBarEventSource.class previousEventSources:@[]];
    [source start];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 40.0);

    [activator la_resetDispatchCounts];
    NSObject *leftView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:leftView bounds:bounds location:CGPointMake(40.0, 10.0) tapCount:1];
    [source la_testingNoteTouchEndedInStatusBarView:leftView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarTapSingleLeft] == 1
            caseName:@"status-bar-single-tap-left"
              reason:@"Left status bar single tap did not dispatch after the tap delay"];

    [activator la_resetDispatchCounts];
    NSObject *centerView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:centerView
                                             bounds:bounds
                                           location:CGPointMake(200.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchEndedInStatusBarView:centerView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    [source la_testingNoteTouchBeganInStatusBarView:centerView
                                             bounds:bounds
                                           location:CGPointMake(200.0, 10.0)
                                           tapCount:2];
    [source la_testingNoteTouchEndedInStatusBarView:centerView tapCount:2];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarTapDouble] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 0
            caseName:@"status-bar-double-tap-cancels-single"
              reason:@"Double tap did not cancel the pending center single tap"];

    [activator la_resetDispatchCounts];
    NSObject *cancelledTapView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:cancelledTapView
                                             bounds:bounds
                                           location:CGPointMake(200.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchMovedInStatusBarView:cancelledTapView bounds:bounds location:CGPointMake(201.0, 10.0)];
    [source la_testingNoteTouchCancelledInStatusBarView:cancelledTapView
                                                 bounds:bounds
                                               location:CGPointMake(201.0, 10.0)
                                               tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 1
            caseName:@"status-bar-cancelled-touch-can-dispatch-single-tap"
              reason:@"Tap-like status bar cancellation did not dispatch a delayed single tap"];

    [activator la_resetDispatchCounts];
    NSObject *cancelledDoubleTapView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:cancelledDoubleTapView
                                             bounds:bounds
                                           location:CGPointMake(360.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchCancelledInStatusBarView:cancelledDoubleTapView
                                                 bounds:bounds
                                               location:CGPointMake(360.0, 10.0)
                                               tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    [source la_testingNoteTouchBeganInStatusBarView:cancelledDoubleTapView
                                             bounds:bounds
                                           location:CGPointMake(360.0, 10.0)
                                           tapCount:2];
    [source la_testingNoteTouchCancelledInStatusBarView:cancelledDoubleTapView
                                                 bounds:bounds
                                               location:CGPointMake(360.0, 10.0)
                                               tapCount:2];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarTapDoubleRight] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingleRight] == 0
            caseName:@"status-bar-cancelled-touch-can-dispatch-double-tap"
              reason:@"Tap-like status bar cancellation did not dispatch double tap or suppress pending single tap"];

    [activator la_resetDispatchCounts];
    NSObject *rightView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:rightView
                                             bounds:bounds
                                           location:CGPointMake(360.0, 10.0)
                                           tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.6];
    [source la_testingNoteTouchEndedInStatusBarView:rightView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarHoldRight] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingleRight] == 0
            caseName:@"status-bar-hold-right-consumes-tap"
              reason:@"Right status bar hold did not consume the follow-up tap"];

    [activator la_resetDispatchCounts];
    NSObject *jitterHoldView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:jitterHoldView
                                             bounds:bounds
                                           location:CGPointMake(200.0, 10.0)
                                           tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    [source la_testingNoteTouchMovedInStatusBarView:jitterHoldView bounds:bounds location:CGPointMake(202.0, 11.0)];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.5];
    [source la_testingNoteTouchEndedInStatusBarView:jitterHoldView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarHold] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 0
            caseName:@"status-bar-hold-survives-small-move"
              reason:@"Small status bar touch movement cancelled hold and fell back to tap"];

    [activator la_resetDispatchCounts];
    NSObject *swipeRightView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:swipeRightView
                                             bounds:bounds
                                           location:CGPointMake(180.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchMovedInStatusBarView:swipeRightView bounds:bounds location:CGPointMake(231.0, 12.0)];
    [source la_testingNoteTouchEndedInStatusBarView:swipeRightView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarSwipeRight] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 0
            caseName:@"status-bar-horizontal-swipe"
              reason:@"Horizontal status bar swipe did not dispatch once and suppress tap"];

    [activator la_resetDispatchCounts];
    NSObject *swipeThenCancelView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:swipeThenCancelView
                                             bounds:bounds
                                           location:CGPointMake(180.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchMovedInStatusBarView:swipeThenCancelView
                                             bounds:bounds
                                           location:CGPointMake(231.0, 12.0)];
    [source la_testingNoteTouchCancelledInStatusBarView:swipeThenCancelView
                                                 bounds:bounds
                                               location:CGPointMake(231.0, 12.0)
                                               tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarSwipeRight] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 0
            caseName:@"status-bar-cancel-after-swipe-does-not-fallback-to-tap"
              reason:@"Cancelled status bar swipe fell back to tap after dispatching swipe"];

    [activator la_resetDispatchCounts];
    NSObject *swipeDownView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:swipeDownView
                                             bounds:bounds
                                           location:CGPointMake(180.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchMovedInStatusBarView:swipeDownView bounds:bounds location:CGPointMake(181.0, 22.0)];
    [source la_testingNoteTouchEndedInStatusBarView:swipeDownView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarSwipeDown] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarHold] == 0
            caseName:@"status-bar-vertical-swipe-down"
              reason:@"Vertical status bar swipe down did not dispatch once and suppress hold"];

    [activator la_resetDispatchCounts];
    NSObject *cancelledView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:cancelledView
                                             bounds:bounds
                                           location:CGPointMake(200.0, 10.0)
                                           tapCount:1];
    [source la_testingNoteTouchCancelledInStatusBarView:cancelledView];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.6];
    [source la_testingNoteTouchEndedInStatusBarView:cancelledView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarHold] == 0 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingle] == 0
            caseName:@"status-bar-cancel-clears-session"
              reason:@"Cancelled status bar touch dispatched a delayed hold or tap"];

    [activator la_resetDispatchCounts];
    NSObject *viewA = [[NSObject alloc] init];
    NSObject *viewB = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:viewA bounds:bounds location:CGPointMake(40.0, 10.0) tapCount:1];
    [source la_testingNoteTouchBeganInStatusBarView:viewB bounds:bounds location:CGPointMake(360.0, 10.0) tapCount:1];
    [source la_testingNoteTouchEndedInStatusBarView:viewA tapCount:1];
    [source la_testingNoteTouchCancelledInStatusBarView:viewB];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameStatusBarTapSingleLeft] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameStatusBarTapSingleRight] == 0
            caseName:@"status-bar-sessions-are-per-view"
              reason:@"A second status bar view cancelled or polluted the first view session"];
}

+ (void)runForceTouchEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    if (![[activator availableEventNames] containsObject:LAEventNameForceTouchScreenBottom]) {
        [recorder skip:@"force-touch-recognizer-logic" reason:@"Force touch metadata is not available on this device"];
        return;
    }

    LATForceTouchEventSource *source =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    [source start];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);
    NSArray<NSDictionary<NSString *, id> *> *regionCases = @[
        @{
            @"Case" : @"force-touch-classifies-statusbar",
            @"EventName" : LAEventNameForceTouchStatusBar,
            @"Location" : [self forceTouchPointWithX:200.0 y:37.0],
        },
        @{
            @"Case" : @"force-touch-classifies-left-edge",
            @"EventName" : LAEventNameForceTouchScreenLeft,
            @"Location" : [self forceTouchPointWithX:13.0 y:400.0],
        },
        @{
            @"Case" : @"force-touch-classifies-right-edge",
            @"EventName" : LAEventNameForceTouchScreenRight,
            @"Location" : [self forceTouchPointWithX:387.0 y:400.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom-left",
            @"EventName" : LAEventNameForceTouchScreenBottomLeft,
            @"Location" : [self forceTouchPointWithX:90.0 y:762.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom",
            @"EventName" : LAEventNameForceTouchScreenBottom,
            @"Location" : [self forceTouchPointWithX:200.0 y:762.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom-right",
            @"EventName" : LAEventNameForceTouchScreenBottomRight,
            @"Location" : [self forceTouchPointWithX:310.0 y:762.0],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in regionCases) {
        CGPoint location = [testCase[@"Location"] CGPointValue];
        NSString *eventName = [source la_testingEventNameForLocation:location bounds:bounds];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSString *topBoundaryEventName = [source la_testingEventNameForLocation:CGPointMake(200.0, 38.0) bounds:bounds];
    NSString *leftBoundaryEventName = [source la_testingEventNameForLocation:CGPointMake(14.0, 400.0) bounds:bounds];
    NSString *rightBoundaryEventName = [source la_testingEventNameForLocation:CGPointMake(386.0, 400.0) bounds:bounds];
    [recorder expect:topBoundaryEventName == nil && leftBoundaryEventName == nil && rightBoundaryEventName == nil
            caseName:@"force-touch-keeps-legacy-region-boundaries-exclusive"
              reason:@"Force touch region classification included points outside legacy strict edge bands"];

    LATForceTouchEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                            bounds:bounds
                                         timestamp:0.0];
    NSString *notStartedEventName = [notStartedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:1 location:CGPointMake(200.0, 762.0) force:5.0],
    ]
                                                                            bounds:bounds
                                                                         timestamp:0.1];
    [recorder expect:notStartedEventName == nil &&
                     [fixture dispatchCountForEventName:LAEventNameForceTouchScreenBottom] == 0
            caseName:@"force-touch-ignores-events-before-start"
              reason:@"Force touch event source dispatched before it was started"];

    LATForceTouchEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    [dispatchSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                          bounds:bounds
                                       timestamp:0.0];
    NSString *belowThresholdEventName = [dispatchSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:1 location:CGPointMake(200.0, 762.0) force:4.99],
    ]
                                                                              bounds:bounds
                                                                           timestamp:0.1];
    NSString *firstEventName = [dispatchSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:1 location:CGPointMake(200.0, 762.0) force:5.0],
    ]
                                                                     bounds:bounds
                                                                  timestamp:0.2];
    NSString *secondEventName = [dispatchSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:1 location:CGPointMake(200.0, 762.0) force:6.0],
    ]
                                                                      bounds:bounds
                                                                   timestamp:0.3];
    [recorder
          expect:belowThresholdEventName == nil && [firstEventName isEqualToString:LAEventNameForceTouchScreenBottom] &&
                 secondEventName == nil && [fixture dispatchCountForEventName:LAEventNameForceTouchScreenBottom] == 1
        caseName:@"force-touch-dispatches-on-threshold-once"
          reason:@"Force touch did not dispatch exactly once when force crossed the threshold"];

    LATForceTouchEventSource *endedSource =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    [endedSource start];
    [activator la_resetDispatchCounts];
    [endedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                       bounds:bounds
                                    timestamp:0.0];
    NSString *endedEventName = [endedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:3 location:CGPointMake(200.0, 762.0) force:6.0],
    ]
                                                                  bounds:bounds
                                                               timestamp:0.1];
    [recorder expect:endedEventName == nil && [fixture dispatchCountForEventName:LAEventNameForceTouchScreenBottom] == 0
            caseName:@"force-touch-ignores-ended-threshold-crossing"
              reason:@"Force touch dispatched after the touch had already ended"];

    LATForceTouchEventSource *movedAwaySource =
        [fixture interestedEventSourceOfClass:LATForceTouchEventSource.class previousEventSources:@[]];
    [movedAwaySource start];
    [activator la_resetDispatchCounts];
    [movedAwaySource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                           bounds:bounds
                                        timestamp:0.0];
    NSString *movedAwayEventName = [movedAwaySource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:1 location:CGPointMake(200.0, 500.0) force:6.0],
    ]
                                                                          bounds:bounds
                                                                       timestamp:0.1];
    [recorder
          expect:movedAwayEventName == nil && [fixture dispatchCountForEventName:LAEventNameForceTouchScreenBottom] == 0
        caseName:@"force-touch-requires-same-region-at-threshold"
          reason:@"Force touch dispatched after the touch moved outside its starting region"];
}

+ (void)runFingerprintSensorEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    if (![[activator availableEventNames] containsObject:LAEventNameFingerprintSensorPressSingle]) {
        [recorder skip:@"fingerprint-sensor-recognizer-logic"
                reason:@"Fingerprint sensor metadata is not available on this device"];
        return;
    }

    LATFingerprintSensorEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [notStartedSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [notStartedSource la_testingResolvePendingSinglePress];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"fingerprint-sensor-ignores-events-before-start"
              reason:@"Fingerprint sensor event source dispatched before it was started"];

    LATFingerprintSensorEventSource *postUnlockSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [postUnlockSource start];
    [activator la_resetDispatchCounts];
    [postUnlockSource noteDeviceUnlockedAtTimestamp:1.0];
    [postUnlockSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:1.1];
    [postUnlockSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:1.2];
    [postUnlockSource la_testingResolvePendingSinglePress];
    [postUnlockSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:1.3];
    [postUnlockSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:1.4];
    [postUnlockSource la_testingResolvePendingSinglePress];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 1
            caseName:@"fingerprint-sensor-ignores-events-after-unlock"
              reason:@"Fingerprint sensor event source did not ignore only the post-unlock suppression window"];

    LATFingerprintSensorEventSource *singlePressSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [singlePressSource start];
    [activator la_resetDispatchCounts];
    [singlePressSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [singlePressSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [singlePressSource la_testingResolvePendingSinglePress];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 1
            caseName:@"fingerprint-sensor-dispatches-single-press"
              reason:@"Fingerprint sensor single press did not dispatch"];

    LATFingerprintSensorEventSource *doublePressSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [doublePressSource start];
    [activator la_resetDispatchCounts];
    [doublePressSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [doublePressSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [doublePressSource la_testingNoteTouchIDDown:YES sequenceState:1 timestamp:0.2];
    [doublePressSource la_testingNoteTouchIDDown:NO sequenceState:2 timestamp:0.3];
    [doublePressSource la_testingResolvePendingSinglePress];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressTwice] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"fingerprint-sensor-dispatches-double-press"
              reason:@"Fingerprint sensor double press did not dispatch or leaked a single press"];

    LATFingerprintSensorEventSource *holdSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [holdSource start];
    [activator la_resetDispatchCounts];
    [holdSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [holdSource la_testingSendShortHoldIfNeeded];
    [holdSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.8];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorHold] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"fingerprint-sensor-dispatches-short-hold"
              reason:@"Fingerprint sensor short hold did not dispatch or leaked a single press"];

    LATFingerprintSensorEventSource *longHoldSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [longHoldSource start];
    [activator la_resetDispatchCounts];
    [longHoldSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [longHoldSource la_testingSendShortHoldIfNeeded];
    [longHoldSource la_testingSendLongHoldIfNeeded];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorHold] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorHoldLong] == 1
            caseName:@"fingerprint-sensor-dispatches-long-hold"
              reason:@"Fingerprint sensor long hold did not dispatch after short hold"];

    LATFingerprintSensorEventSource *pressHoldSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [pressHoldSource start];
    [activator la_resetDispatchCounts];
    [pressHoldSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [pressHoldSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [pressHoldSource la_testingNoteTouchIDDown:YES sequenceState:1 timestamp:0.2];
    [pressHoldSource la_testingSendShortHoldIfNeeded];
    [recorder expect:[fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndHold] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressTwice] == 0 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"fingerprint-sensor-dispatches-single-press-with-hold"
              reason:@"Fingerprint sensor single press with hold did not dispatch or leaked another press event"];

    LATFingerprintSensorEventSource *slideInSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    [slideInSource start];
    [activator la_resetDispatchCounts];
    [slideInSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [slideInSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    BOOL consumed = [slideInSource consumePendingSinglePressForSlideInAtTimestamp:0.4];
    [slideInSource la_testingResolvePendingSinglePress];
    [recorder expect:consumed &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndSlideIn] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"fingerprint-sensor-dispatches-single-press-with-slide-in"
              reason:@"Fingerprint sensor single press with slide-in did not dispatch or leaked a single press"];
}

+ (void)runEdgeGestureEventSourceDispatchTestsWithRecorder:(LATestRecorder *)recorder
                                                 activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);

    LATEdgeGestureEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                          [self edgeGesturePointWithX:200.0 y:798.0],
                      ]
                                                                                     phase:0]
                                            bounds:bounds
                                         timestamp:0.0];
    NSString *notStartedEventName = [notStartedSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                          y:700.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.1];
    [recorder expect:notStartedEventName == nil && [fixture dispatchCountForEventName:LAEventNameSlideInFromBottom] == 0
            caseName:@"edge-gesture-event-source-ignores-events-before-start"
              reason:@"Edge gesture event source dispatched before it was started"];

    LATEdgeGestureEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    [dispatchSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                        [self edgeGesturePointWithX:200.0 y:798.0],
                    ]
                                                                                   phase:0]
                                          bounds:bounds
                                       timestamp:0.0];
    NSString *firstEventName = [dispatchSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                          y:700.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.1];
    NSString *secondEventName = [dispatchSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                          y:650.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.2];
    [recorder expect:[firstEventName isEqualToString:LAEventNameSlideInFromBottom] && secondEventName == nil &&
                     [fixture dispatchCountForEventName:LAEventNameSlideInFromBottom] == 1
            caseName:@"edge-gesture-event-source-dispatches-once"
              reason:@"Edge gesture event source did not dispatch exactly once for a classified gesture"];

    LATEdgeGestureEventSource *shortMoveSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    [shortMoveSource start];
    [activator la_resetDispatchCounts];
    [shortMoveSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                         [self edgeGesturePointWithX:200.0 y:798.0],
                     ]
                                                                                    phase:0]
                                           bounds:bounds
                                        timestamp:0.0];
    NSString *shortMoveEventName = [shortMoveSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                          y:750.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.1];
    [recorder expect:shortMoveEventName == nil && [fixture dispatchCountForEventName:LAEventNameSlideInFromBottom] == 0
            caseName:@"edge-gesture-event-source-ignores-unclassified-move"
              reason:@"Edge gesture event source dispatched for an unclassified gesture"];

    LATEdgeGestureEventSource *dragAlongSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    [dragAlongSource start];
    [activator la_resetDispatchCounts];
    [dragAlongSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                         [self edgeGesturePointWithX:120.0 y:788.0],
                     ]
                                                                                    phase:0]
                                           bounds:bounds
                                        timestamp:0.0];
    NSString *dragAlongEventName = [dragAlongSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:160.0
                                                                                                          y:788.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.1];
    [recorder expect:[dragAlongEventName isEqualToString:LAEventScreenBottomSwipeRight] &&
                     [fixture dispatchCountForEventName:LAEventScreenBottomSwipeRight] == 1
            caseName:@"edge-gesture-event-source-dispatches-drag-along"
              reason:@"Edge gesture event source did not dispatch a classified drag-along gesture"];

    LATEdgeGestureEventSource *dragOffSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class previousEventSources:@[]];
    [dragOffSource start];
    [activator la_resetDispatchCounts];
    [dragOffSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                       [self edgeGesturePointWithX:200.0 y:400.0],
                   ]
                                                                                  phase:0]
                                         bounds:bounds
                                      timestamp:0.0];
    NSString *dragOffMoveEventName = [dragOffSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:10.0
                                                                                                          y:400.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.1];
    NSString *dragOffEventName = [dragOffSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:10.0
                                                                                                          y:400.0] ]
                                                                       phase:3]
                              bounds:bounds
                           timestamp:0.2];
    [recorder expect:dragOffMoveEventName == nil && [dragOffEventName isEqualToString:LAEventNameDragOffLeft] &&
                     [fixture dispatchCountForEventName:LAEventNameDragOffLeft] == 1
            caseName:@"edge-gesture-event-source-dispatches-drag-off"
              reason:@"Edge gesture event source did not dispatch drag-off exactly once on touch end"];

    LATFingerprintSensorEventSource *fingerprintSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    BOOL fingerprintEventAvailable =
        [[activator availableEventNames] containsObject:LAEventNameFingerprintSensorPressSingle];
    [recorder expect:(fingerprintSource != nil) == fingerprintEventAvailable
            caseName:@"edge-gesture-fingerprint-composite-matches-device-capability"
              reason:@"Fingerprint composite acquisition did not match the registered device capability"];
    if (!fingerprintSource) {
        return;
    }
    [fingerprintSource start];
    LATEdgeGestureEventSource *fingerprintEdgeSource =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class
                         previousEventSources:@[ fingerprintSource ]];
    [fingerprintEdgeSource start];
    [activator la_resetDispatchCounts];
    [fingerprintSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [fingerprintSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [fingerprintEdgeSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                               [self edgeGesturePointWithX:200.0 y:798.0],
                           ]
                                                                                          phase:0]
                                                 bounds:bounds
                                              timestamp:0.2];
    NSString *fingerprintSlideEventName = [fingerprintEdgeSource
        la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                          y:700.0] ]
                                                                       phase:1]
                              bounds:bounds
                           timestamp:0.4];
    [fingerprintSource la_testingResolvePendingSinglePress];
    [recorder expect:[fingerprintSlideEventName isEqualToString:LAEventNameFingerprintSensorPressSingleAndSlideIn] &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndSlideIn] == 1 &&
                     [fixture dispatchCountForEventName:LAEventNameSlideInFromBottom] == 0 &&
                     [fixture dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle] == 0
            caseName:@"edge-gesture-routes-bottom-slide-to-fingerprint-slide-in"
              reason:@"Bottom slide after fingerprint press did not route to the fingerprint slide-in event"];
}

+ (void)runSpringBoardIconGestureEventSourceTestsWithRecorder:(LATestRecorder *)recorder
                                                    activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);

    LATSpringBoardIconGestureEventSource *deferredAttachmentSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    UIScrollView *existingIconScrollView = [[UIScrollView alloc] initWithFrame:bounds];
    existingIconScrollView.minimumZoomScale = 1.0;
    [deferredAttachmentSource noteIconScrollViewDidInitialize:existingIconScrollView];
    BOOL capturedBeforeStart = [deferredAttachmentSource la_testingKnownIconScrollViewCount] == 1 &&
                               ![deferredAttachmentSource la_testingIsInstalledInIconScrollView:existingIconScrollView];
    [deferredAttachmentSource start];
    [recorder
          expect:capturedBeforeStart &&
                 [deferredAttachmentSource la_testingIsInstalledInIconScrollView:existingIconScrollView] &&
                 existingIconScrollView.minimumZoomScale == 0.95
        caseName:@"springboard-icon-gesture-attaches-to-existing-scroll-view"
          reason:@"SpringBoard icon source did not retain and activate an icon scroll view created before interest"];
    [deferredAttachmentSource invalidate];

    LATSpringBoardIconGestureEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    NSString *notStartedEventName = [notStartedSource la_testingHandlePinchScale:0.94
                                                                           state:UIGestureRecognizerStateChanged
                                                                          bounds:bounds];
    [recorder expect:notStartedEventName == nil && [fixture dispatchCountForEventName:LAEventNameSpringBoardPinch] == 0
            caseName:@"springboard-icon-gesture-ignores-events-before-start"
              reason:@"SpringBoard icon gesture source dispatched before it was started"];

    LATSpringBoardIconGestureEventSource *pinchSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    [pinchSource start];
    [activator la_resetDispatchCounts];
    [pinchSource la_testingHandlePinchScale:1.0 state:UIGestureRecognizerStateBegan bounds:bounds];
    NSString *pinchAtThresholdEventName = [pinchSource la_testingHandlePinchScale:0.95
                                                                            state:UIGestureRecognizerStateChanged
                                                                           bounds:bounds];
    NSString *pinchBelowThresholdEventName = [pinchSource la_testingHandlePinchScale:0.94
                                                                               state:UIGestureRecognizerStateChanged
                                                                              bounds:bounds];
    NSString *secondPinchEventName = [pinchSource la_testingHandlePinchScale:0.90
                                                                       state:UIGestureRecognizerStateChanged
                                                                      bounds:bounds];
    [recorder expect:pinchAtThresholdEventName == nil &&
                     [pinchBelowThresholdEventName isEqualToString:LAEventNameSpringBoardPinch] &&
                     secondPinchEventName == nil && [fixture dispatchCountForEventName:LAEventNameSpringBoardPinch] == 1
            caseName:@"springboard-icon-gesture-dispatches-pinch-once"
              reason:@"SpringBoard icon pinch threshold or once-per-session behavior was wrong"];
    [pinchSource invalidate];

    LATSpringBoardIconGestureEventSource *spreadSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    [spreadSource start];
    [activator la_resetDispatchCounts];
    [spreadSource la_testingHandlePinchScale:1.0 state:UIGestureRecognizerStateBegan bounds:bounds];
    NSString *spreadAtThresholdEventName = [spreadSource la_testingHandlePinchScale:1.05
                                                                              state:UIGestureRecognizerStateChanged
                                                                             bounds:bounds];
    NSString *spreadAboveThresholdEventName = [spreadSource la_testingHandlePinchScale:1.06
                                                                                 state:UIGestureRecognizerStateChanged
                                                                                bounds:bounds];
    NSString *secondSpreadEventName = [spreadSource la_testingHandlePinchScale:1.10
                                                                         state:UIGestureRecognizerStateChanged
                                                                        bounds:bounds];
    [recorder
          expect:spreadAtThresholdEventName == nil &&
                 [spreadAboveThresholdEventName isEqualToString:LAEventNameSpringBoardSpread] &&
                 secondSpreadEventName == nil && [fixture dispatchCountForEventName:LAEventNameSpringBoardSpread] == 1
        caseName:@"springboard-icon-gesture-dispatches-spread-once"
          reason:@"SpringBoard icon spread threshold or once-per-session behavior was wrong"];
    [spreadSource invalidate];

    LATSpringBoardIconGestureEventSource *resetSource =
        [fixture interestedEventSourceOfClass:LATSpringBoardIconGestureEventSource.class previousEventSources:@[]];
    [resetSource start];
    [activator la_resetDispatchCounts];
    [resetSource la_testingHandlePinchScale:1.0 state:UIGestureRecognizerStateBegan bounds:bounds];
    NSString *cancelledEventName = [resetSource la_testingHandlePinchScale:0.94
                                                                     state:UIGestureRecognizerStateCancelled
                                                                    bounds:bounds];
    BOOL cancelledReset = ![resetSource la_testingHasRecognitionState];
    [resetSource la_testingHandlePinchScale:1.0 state:UIGestureRecognizerStateBegan bounds:bounds];
    NSString *afterCancelEventName = [resetSource la_testingHandlePinchScale:1.06
                                                                       state:UIGestureRecognizerStateChanged
                                                                      bounds:bounds];
    [resetSource la_testingHandlePinchScale:1.06 state:UIGestureRecognizerStateEnded bounds:bounds];
    [recorder expect:cancelledEventName == nil && cancelledReset &&
                     [afterCancelEventName isEqualToString:LAEventNameSpringBoardSpread] &&
                     ![resetSource la_testingHasRecognitionState] &&
                     [fixture dispatchCountForEventName:LAEventNameSpringBoardSpread] == 1
            caseName:@"springboard-icon-gesture-cancel-and-end-reset-session"
              reason:@"SpringBoard icon source did not reset state after cancellation or end"];

    [resetSource invalidate];
}

+ (void)runMotionEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATMotionEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATMotionEventSource.class previousEventSources:@[]];
    [recorder expect:[notStartedSource.eventNames isEqualToSet:[NSSet setWithObject:LAEventNameMotionShake]] &&
                     notStartedSource.interestPolicy == LATEventSourceInterestPolicyAlways
            caseName:@"motion-event-source-declares-always-on-catalog"
              reason:@"Motion source did not declare its exact producer catalog and always-on policy"];
    [activator la_resetDispatchCounts];
    BOOL dispatchedBeforeStart = [notStartedSource la_testingNoteMotionEnded:UIEventSubtypeMotionShake];
    [notStartedSource start];
    BOOL dispatchedNonShake = [notStartedSource la_testingNoteMotionEnded:UIEventSubtypeNone];
    [recorder expect:!dispatchedBeforeStart && !dispatchedNonShake &&
                     [fixture dispatchCountForEventName:LAEventNameMotionShake] == 0
            caseName:@"motion-event-source-filters-lifecycle-and-subtype"
              reason:@"Motion source dispatched before startup or for a non-shake subtype"];
    [notStartedSource invalidate];

    LATMotionEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATMotionEventSource.class previousEventSources:@[]];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    BOOL dispatchedFirstShake = [dispatchSource la_testingNoteMotionEnded:UIEventSubtypeMotionShake];
    BOOL dispatchedSecondShake = [dispatchSource la_testingNoteMotionEnded:UIEventSubtypeMotionShake];
    [recorder expect:dispatchedFirstShake && dispatchedSecondShake &&
                     [fixture dispatchCountForEventName:LAEventNameMotionShake] == 2
            caseName:@"motion-event-source-dispatches-each-shake-callback"
              reason:@"Motion source coalesced distinct shake callbacks"];

    [dispatchSource invalidate];
    BOOL dispatchedAfterInvalidation = [dispatchSource la_testingNoteMotionEnded:UIEventSubtypeMotionShake];
    [recorder expect:!dispatchedAfterInvalidation && [fixture dispatchCountForEventName:LAEventNameMotionShake] == 2
            caseName:@"motion-event-source-invalidation-is-terminal"
              reason:@"Invalidated Motion source continued dispatching shake events"];
}

+ (void)runVolumeHUDTapEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATVolumeHUDTapEventSource *attachmentSource =
        [fixture interestedEventSourceOfClass:LATVolumeHUDTapEventSource.class previousEventSources:@[]];
    UIView *sliderContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 68.0, 220.0)];
    [attachmentSource noteVolumeHUDSliderContainerViewDidLoad:sliderContainerView];
    BOOL capturedBeforeStart = [attachmentSource la_testingKnownSliderContainerViewCount] == 1 &&
                               ![attachmentSource la_testingIsInstalledInSliderContainerView:sliderContainerView];
    [attachmentSource start];
    UITapGestureRecognizer *recognizer = (UITapGestureRecognizer *)sliderContainerView.gestureRecognizers.firstObject;
    [recorder
          expect:capturedBeforeStart &&
                 [attachmentSource la_testingIsInstalledInSliderContainerView:sliderContainerView] &&
                 sliderContainerView.gestureRecognizers.count == 1 &&
                 [recognizer isKindOfClass:UITapGestureRecognizer.class] && recognizer.numberOfTapsRequired == 1 &&
                 !recognizer.cancelsTouchesInView && !recognizer.delaysTouchesBegan && !recognizer.delaysTouchesEnded
        caseName:@"volume-hud-tap-source-attaches-non-cancelling-recognizer"
          reason:@"Volume HUD tap source did not attach its always-on recognizer without changing HUD touch delivery"];
    [attachmentSource invalidate];
    [recorder expect:sliderContainerView.gestureRecognizers.count == 0 &&
                     ![attachmentSource la_testingIsInstalledInSliderContainerView:sliderContainerView]
            caseName:@"volume-hud-tap-source-removes-recognizer-on-invalidate"
              reason:@"Invalidated Volume HUD tap source left its recognizer attached"];

    LATVolumeHUDTapEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATVolumeHUDTapEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    BOOL dispatchedBeforeStart = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded];
    [dispatchSource start];
    BOOL dispatchedChanged = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateChanged];
    BOOL dispatchedEnded = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded];
    [recorder expect:!dispatchedBeforeStart && !dispatchedChanged && dispatchedEnded &&
                     [fixture dispatchCountForEventName:LAEventNameVolumeDisplayTap] == 1
            caseName:@"volume-hud-tap-source-dispatches-only-ended-taps"
              reason:@"Volume HUD tap source did not match the 1.9.13 ended-state dispatch contract"];
    [dispatchSource invalidate];
    BOOL dispatchedAfterInvalidation = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded];
    [recorder
          expect:!dispatchedAfterInvalidation && [fixture dispatchCountForEventName:LAEventNameVolumeDisplayTap] == 1
        caseName:@"volume-hud-tap-source-invalidation-is-terminal"
          reason:@"Invalidated Volume HUD tap source continued dispatching events"];
}

+ (void)runGestureBarEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATGestureBarEventSource *attachmentSource =
        [fixture interestedEventSourceOfClass:LATGestureBarEventSource.class previousEventSources:@[]];
    BOOL eventIsAvailable = [[activator availableEventNames] containsObject:LAEventNameGestureBarTapDouble];
    if (!eventIsAvailable) {
        [recorder expect:attachmentSource == nil
                caseName:@"gesture-bar-source-skips-non-fake-home-devices"
                  reason:@"Gesture bar source registered without its fake-home-button event definition"];
        return;
    }

    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    recognizer.numberOfTapsRequired = 2;
    recognizer.cancelsTouchesInView = NO;
    [attachmentSource noteGestureBarDoubleTapRecognizerDidLoad:recognizer];
    [attachmentSource noteGestureBarDoubleTapRecognizerDidLoad:recognizer];
    BOOL capturedBeforeStart = [attachmentSource la_testingKnownRecognizerCount] == 1 &&
                               ![attachmentSource la_testingIsAttachedToRecognizer:recognizer];
    [attachmentSource start];
    [recorder expect:capturedBeforeStart && [attachmentSource la_testingIsAttachedToRecognizer:recognizer] &&
                     recognizer.numberOfTapsRequired == 2 && !recognizer.cancelsTouchesInView
            caseName:@"gesture-bar-source-targets-system-double-tap-recognizer"
              reason:@"Gesture bar source did not attach once without changing the system recognizer contract"];
    [attachmentSource invalidate];
    [recorder expect:![attachmentSource la_testingIsAttachedToRecognizer:recognizer]
            caseName:@"gesture-bar-source-removes-target-on-invalidate"
              reason:@"Invalidated gesture bar source kept its target attachment"];

    LATGestureBarEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATGestureBarEventSource.class previousEventSources:@[]];
    CGRect bounds = CGRectMake(0.0, 0.0, 414.0, 896.0);
    [activator la_resetDispatchCounts];
    BOOL dispatchedBeforeStart = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded
                                                                 location:CGPointMake(180.0, 881.0)
                                                                   bounds:bounds];
    [dispatchSource start];
    BOOL dispatchedChanged = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateChanged
                                                             location:CGPointMake(180.0, 881.0)
                                                               bounds:bounds];
    BOOL dispatchedOutsideBottomRegion = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded
                                                                         location:CGPointMake(180.0, 865.0)
                                                                           bounds:bounds];
    BOOL dispatchedAtBottomBoundary = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded
                                                                      location:CGPointMake(180.0, 866.0)
                                                                        bounds:bounds];
    [recorder
          expect:!dispatchedBeforeStart && !dispatchedChanged && !dispatchedOutsideBottomRegion &&
                 dispatchedAtBottomBoundary && [fixture dispatchCountForEventName:LAEventNameGestureBarTapDouble] == 1
        caseName:@"gesture-bar-source-dispatches-ended-taps-in-bottom-thirty-points"
          reason:@"Gesture bar source did not preserve the 1.9.13 state and bottom-region gates"];
    [dispatchSource invalidate];
    BOOL dispatchedAfterInvalidation = [dispatchSource la_testingHandleTapState:UIGestureRecognizerStateEnded
                                                                       location:CGPointMake(180.0, 881.0)
                                                                         bounds:bounds];
    [recorder
          expect:!dispatchedAfterInvalidation && [fixture dispatchCountForEventName:LAEventNameGestureBarTapDouble] == 1
        caseName:@"gesture-bar-source-invalidation-is-terminal"
          reason:@"Invalidated gesture bar source continued dispatching events"];
}

+ (void)runLockScreenClockEventSourceTestsWithRecorder:(LATestRecorder *)recorder
                                              activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATLockScreenClockEventSource *attachmentSource =
        [fixture interestedEventSourceOfClass:LATLockScreenClockEventSource.class previousEventSources:@[]];
    UIView *rootView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 414.0, 896.0)];
    UIView *parentView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 414.0, 896.0)];
    UIView *clockView = [[UIView alloc] initWithFrame:CGRectMake(8.0, 95.0, 398.0, 128.5)];
    rootView.userInteractionEnabled = NO;
    parentView.userInteractionEnabled = NO;
    clockView.userInteractionEnabled = NO;
    [rootView addSubview:parentView];
    [parentView addSubview:clockView];
    [attachmentSource noteLockScreenClockViewDidLoad:clockView];
    [attachmentSource noteLockScreenClockViewDidLoad:clockView];
    BOOL capturedBeforeStart = [attachmentSource la_testingKnownClockViewCount] == 1 &&
                               [attachmentSource la_testingInstalledRecognizersInClockView:clockView] == nil &&
                               !rootView.userInteractionEnabled && !parentView.userInteractionEnabled &&
                               !clockView.userInteractionEnabled;
    [attachmentSource start];

    NSArray<UIGestureRecognizer *> *recognizers =
        [attachmentSource la_testingInstalledRecognizersInClockView:clockView];
    UITapGestureRecognizer *doubleTapRecognizer = nil;
    UILongPressGestureRecognizer *longPressRecognizer = nil;
    NSMutableSet<NSNumber *> *swipeDirections = [[NSMutableSet alloc] init];
    BOOL allRecognizersUseSourceDelegate = YES;
    for (UIGestureRecognizer *recognizer in recognizers) {
        allRecognizersUseSourceDelegate =
            allRecognizersUseSourceDelegate && recognizer.delegate == (id<UIGestureRecognizerDelegate>)attachmentSource;
        if ([recognizer isKindOfClass:UITapGestureRecognizer.class]) {
            doubleTapRecognizer = (UITapGestureRecognizer *)recognizer;
        } else if ([recognizer isKindOfClass:UILongPressGestureRecognizer.class]) {
            longPressRecognizer = (UILongPressGestureRecognizer *)recognizer;
        } else if ([recognizer isKindOfClass:UISwipeGestureRecognizer.class]) {
            [swipeDirections addObject:@(((UISwipeGestureRecognizer *)recognizer).direction)];
        }
    }
    BOOL allowsSimultaneousRecognition = [(id<UIGestureRecognizerDelegate>)attachmentSource
                             gestureRecognizer:doubleTapRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:longPressRecognizer];
    [recorder
          expect:capturedBeforeStart && rootView.userInteractionEnabled && parentView.userInteractionEnabled &&
                 clockView.userInteractionEnabled &&
                 recognizers.count == 5 && doubleTapRecognizer.numberOfTapsRequired == 2 &&
                 longPressRecognizer.minimumPressDuration == 0.5 && allRecognizersUseSourceDelegate &&
                 allowsSimultaneousRecognition &&
                 [swipeDirections isEqualToSet:[NSSet setWithObjects:@(UISwipeGestureRecognizerDirectionLeft),
                                                                     @(UISwipeGestureRecognizerDirectionRight),
                                                                     @(UISwipeGestureRecognizerDirectionDown), nil]]
        caseName:@"lock-screen-clock-source-installs-legacy-recognizers"
          reason:@"Lock screen clock source did not preserve the 1.9.13 recognizer and interaction contract"];
    UIView *clockHitView = [attachmentSource lockScreenClockHitViewForContainerView:rootView
                                                                              point:CGPointMake(20.0, 110.0)
                                                                          withEvent:nil];
    UIView *outsideHitView = [attachmentSource lockScreenClockHitViewForContainerView:rootView
                                                                                point:CGPointMake(20.0, 300.0)
                                                                            withEvent:nil];
    UIView *unrelatedView = [[UIView alloc] initWithFrame:parentView.bounds];
    UIView *unrelatedHitView = [attachmentSource lockScreenClockHitViewForContainerView:unrelatedView
                                                                                  point:CGPointMake(20.0, 110.0)
                                                                              withEvent:nil];
    [recorder expect:clockHitView == clockView && outsideHitView == nil && unrelatedHitView == nil
            caseName:@"lock-screen-clock-source-routes-pass-through-hits"
              reason:@"Lock screen clock source did not route pass-through hits back into the active clock view"];
    UIView *preciseClockView = [[UIView alloc] initWithFrame:clockView.frame];
    [parentView addSubview:preciseClockView];
    [attachmentSource notePreciseLockScreenClockViewDidLoad:preciseClockView];
    UIView *lateLegacyClockView = [[UIView alloc] initWithFrame:clockView.frame];
    [parentView addSubview:lateLegacyClockView];
    [attachmentSource noteLockScreenClockViewDidLoad:lateLegacyClockView];
    [recorder
          expect:clockView.gestureRecognizers.count == 0 &&
                 [attachmentSource la_testingInstalledRecognizersInClockView:clockView] == nil &&
                 [attachmentSource la_testingInstalledRecognizersInClockView:preciseClockView].count == 5 &&
                 [attachmentSource la_testingInstalledRecognizersInClockView:lateLegacyClockView] == nil &&
                 [attachmentSource la_testingKnownClockViewCount] == 1
        caseName:@"lock-screen-clock-source-prefers-observed-precise-clock-view"
          reason:@"Lock screen clock source did not replace legacy candidates after observing a precise clock view"];
    [attachmentSource invalidate];
    [recorder expect:clockView.gestureRecognizers.count == 0 && !rootView.userInteractionEnabled &&
                     preciseClockView.gestureRecognizers.count == 0 && !parentView.userInteractionEnabled &&
                     !clockView.userInteractionEnabled &&
                     [attachmentSource la_testingInstalledRecognizersInClockView:clockView] == nil
            caseName:@"lock-screen-clock-source-removes-recognizers-on-invalidate"
              reason:@"Invalidated lock screen clock source left recognizers or interaction changes behind"];

    LATLockScreenClockEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATLockScreenClockEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    BOOL dispatchedBeforeStart =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockDoubleTap];
    [dispatchSource start];
    BOOL dispatchedDoubleTap =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockDoubleTap];
    BOOL dispatchedHoldAtEnd =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockTapHold];
    BOOL dispatchedHoldAtBegin =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateBegan
                                              eventName:LAEventNameLockScreenClockTapHold];
    BOOL dispatchedSwipeLeft =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockSwipeLeft];
    BOOL dispatchedSwipeRight =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockSwipeRight];
    BOOL dispatchedSwipeDown =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockSwipeDown];
    [recorder
          expect:!dispatchedBeforeStart && dispatchedDoubleTap && !dispatchedHoldAtEnd && dispatchedHoldAtBegin &&
                 dispatchedSwipeLeft && dispatchedSwipeRight && dispatchedSwipeDown &&
                 [fixture dispatchCountForEventName:LAEventNameLockScreenClockDoubleTap] == 1 &&
                 [fixture dispatchCountForEventName:LAEventNameLockScreenClockTapHold] == 1 &&
                 [fixture dispatchCountForEventName:LAEventNameLockScreenClockSwipeLeft] == 1 &&
                 [fixture dispatchCountForEventName:LAEventNameLockScreenClockSwipeRight] == 1 &&
                 [fixture dispatchCountForEventName:LAEventNameLockScreenClockSwipeDown] == 1
        caseName:@"lock-screen-clock-source-dispatches-legacy-recognizer-states"
          reason:@"Lock screen clock source did not dispatch long press at began and completed gestures at ended"];
    [dispatchSource invalidate];
    BOOL dispatchedAfterInvalidation =
        [dispatchSource la_testingHandleRecognizerState:UIGestureRecognizerStateEnded
                                              eventName:LAEventNameLockScreenClockDoubleTap];
    [recorder expect:!dispatchedAfterInvalidation &&
                     [fixture dispatchCountForEventName:LAEventNameLockScreenClockDoubleTap] == 1
            caseName:@"lock-screen-clock-source-invalidation-is-terminal"
              reason:@"Invalidated lock screen clock source continued dispatching events"];
}

+ (void)runMultiTouchEventSourceDispatchTestsWithRecorder:(LATestRecorder *)recorder
                                                activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);

    LATMultiTouchEventSource *notStartedSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                                   phase:UITouchPhaseBegan
                                                  bounds:bounds
                                               timestamp:0.0];
    NSString *notStartedEventName = [notStartedSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:130.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:270.0 y:200.0],
    ]
                                                                                   phase:UITouchPhaseMoved
                                                                                  bounds:bounds
                                                                               timestamp:0.1];
    [recorder expect:notStartedEventName == nil && [fixture dispatchCountForEventName:LAEventNameThreeFingerPinch] == 0
            caseName:@"multi-touch-event-source-ignores-events-before-start"
              reason:@"Multi-touch event source dispatched before it was started"];

    LATMultiTouchEventSource *dispatchSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    [dispatchSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                                 phase:UITouchPhaseBegan
                                                bounds:bounds
                                             timestamp:0.0];
    NSString *firstEventName = [dispatchSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:130.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:270.0 y:200.0],
    ]
                                                                            phase:UITouchPhaseMoved
                                                                           bounds:bounds
                                                                        timestamp:0.1];
    NSString *secondEventName = [dispatchSource la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:140.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:260.0 y:200.0],
    ]
                                                                             phase:UITouchPhaseMoved
                                                                            bounds:bounds
                                                                         timestamp:0.2];
    [recorder expect:[firstEventName isEqualToString:LAEventNameThreeFingerPinch] && secondEventName == nil &&
                     [fixture dispatchCountForEventName:LAEventNameThreeFingerPinch] == 1
            caseName:@"multi-touch-event-source-dispatches-once"
              reason:@"Multi-touch event source did not dispatch exactly once for a classified gesture"];

    LATMultiTouchEventSource *tapSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    [tapSource start];
    [activator la_resetDispatchCounts];
    NSArray<NSValue *> *tapLocations = @[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ];
    [tapSource la_testingUpdateWithTouchLocations:tapLocations phase:UITouchPhaseBegan bounds:bounds timestamp:0.0];
    NSString *tapEventName = [tapSource la_testingUpdateWithTouchLocations:tapLocations
                                                                     phase:UITouchPhaseEnded
                                                                    bounds:bounds
                                                                 timestamp:0.1];
    [recorder expect:[tapEventName isEqualToString:LAEventNameThreeFingerTap] &&
                     [fixture dispatchCountForEventName:LAEventNameThreeFingerTap] == 1
            caseName:@"multi-touch-event-source-dispatches-tap"
              reason:@"Multi-touch event source did not dispatch a completed tap"];

    LATMultiTouchEventSource *invalidSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    [invalidSource start];
    [activator la_resetDispatchCounts];
    NSString *twoFingerEventName = [self classifiedMultiTouchEventNameWithEventSource:invalidSource
                                                                               bounds:bounds
                                                                       startLocations:@[
                                                                           [self multiTouchPointWithX:100.0 y:200.0],
                                                                           [self multiTouchPointWithX:300.0 y:200.0],
                                                                       ]
                                                                        moveLocations:@[
                                                                            [self multiTouchPointWithX:150.0 y:200.0],
                                                                            [self multiTouchPointWithX:250.0 y:200.0],
                                                                        ]];
    [recorder expect:twoFingerEventName == nil && [fixture dispatchCountForEventName:LAEventNameThreeFingerPinch] == 0
            caseName:@"multi-touch-event-source-ignores-two-finger-session"
              reason:@"Multi-touch event source dispatched for an unsupported two-finger session"];

    LATMultiTouchEventSource *sixFingerSource =
        [fixture interestedEventSourceOfClass:LATMultiTouchEventSource.class previousEventSources:@[]];
    [sixFingerSource start];
    [activator la_resetDispatchCounts];
    NSString *sixFingerEventName = [self classifiedMultiTouchEventNameWithEventSource:sixFingerSource
                                                                               bounds:bounds
                                                                       startLocations:@[
                                                                           [self multiTouchPointWithX:0.0 y:200.0],
                                                                           [self multiTouchPointWithX:80.0 y:200.0],
                                                                           [self multiTouchPointWithX:160.0 y:200.0],
                                                                           [self multiTouchPointWithX:240.0 y:200.0],
                                                                           [self multiTouchPointWithX:320.0 y:200.0],
                                                                           [self multiTouchPointWithX:400.0 y:200.0],
                                                                       ]
                                                                        moveLocations:@[
                                                                            [self multiTouchPointWithX:0.0 y:200.0],
                                                                            [self multiTouchPointWithX:70.0 y:200.0],
                                                                            [self multiTouchPointWithX:140.0 y:200.0],
                                                                            [self multiTouchPointWithX:260.0 y:200.0],
                                                                            [self multiTouchPointWithX:330.0 y:200.0],
                                                                            [self multiTouchPointWithX:400.0 y:200.0],
                                                                        ]];
    [recorder expect:sixFingerEventName == nil && [fixture dispatchCountForEventName:LAEventNameFiveFingerSpread] == 0
            caseName:@"multi-touch-event-source-ignores-six-finger-session"
              reason:@"Multi-touch event source dispatched for an unsupported six-finger session"];
}

+ (NSString *)classifiedMultiTouchEventNameWithEventSource:(LATMultiTouchEventSource *)source
                                                    bounds:(CGRect)bounds
                                            startLocations:(NSArray<NSValue *> *)startLocations
                                             moveLocations:(NSArray<NSValue *> *)moveLocations {
    [source la_testingUpdateWithTouchLocations:startLocations phase:UITouchPhaseBegan bounds:bounds timestamp:0.0];
    return [source la_testingUpdateWithTouchLocations:moveLocations
                                                phase:UITouchPhaseMoved
                                               bounds:bounds
                                            timestamp:0.1];
}

+ (NSValue *)edgeGesturePointWithX:(CGFloat)x y:(CGFloat)y {
    return [NSValue valueWithCGPoint:CGPointMake(x, y)];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)edgeGestureSnapshotsWithLocations:(NSArray<NSValue *> *)locations
                                                                         phase:(NSInteger)phase {
    NSMutableArray<NSDictionary<NSString *, id> *> *snapshots = [[NSMutableArray alloc] init];
    [locations enumerateObjectsUsingBlock:^(NSValue *locationValue, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSString *identifier = [NSString stringWithFormat:@"touch-%lu", (unsigned long)index];
        [snapshots addObject:@{
            @"Identifier" : identifier,
            @"Phase" : @(phase),
            @"Location" : locationValue,
        }];
    }];
    return snapshots;
}

+ (NSValue *)multiTouchPointWithX:(CGFloat)x y:(CGFloat)y {
    return [NSValue valueWithCGPoint:CGPointMake(x, y)];
}

+ (NSValue *)forceTouchPointWithX:(CGFloat)x y:(CGFloat)y {
    return [NSValue valueWithCGPoint:CGPointMake(x, y)];
}

+ (NSDictionary<NSString *, id> *)forceTouchSnapshotWithIdentifier:(NSString *)identifier
                                                             phase:(NSInteger)phase
                                                          location:(CGPoint)location
                                                             force:(CGFloat)force {
    return @{
        @"Identifier" : identifier,
        @"Force" : @(force),
        @"Phase" : @(phase),
        @"Location" : [NSValue valueWithCGPoint:location],
    };
}

@end
