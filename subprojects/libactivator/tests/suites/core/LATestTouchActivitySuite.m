//
//  LATestTouchActivitySuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestTouchActivitySuite.h"

#import "LATestEnvironment.h"

@implementation LATestTouchActivitySuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"TouchActivity"];

    LATouchActivityTracker *tracker = [[LATouchActivityTracker alloc] init];
    __block NSInteger immediateCount = 0;
    [tracker performWhenTouchesEnd:^{
        immediateCount += 1;
    }];
    [LATestEnvironment waitForMainQueue];
    [recorder expect:immediateCount == 1
            caseName:@"inactive-runs-immediately"
              reason:@"Inactive touch tracker did not run pending work immediately"];

    LATestTouch *touch = [[LATestTouch alloc] init];
    LATestTouchEvent *event = [[LATestTouchEvent alloc] init];
    event.testTouches = [NSSet setWithObject:touch];

    touch.testPhase = UITouchPhaseBegan;
    [tracker noteTouchEvent:event];
    [recorder expect:tracker.touchActive
            caseName:@"touch-began-active"
              reason:@"Touch began did not mark tracker active"];

    __block NSInteger pendingCount = 0;
    [tracker performWhenTouchesEnd:^{
        pendingCount += 1;
    }];
    [tracker performWhenTouchesEnd:^{
        pendingCount += 1;
    }];
    [LATestEnvironment waitForMainQueue];
    [recorder expect:pendingCount == 0
            caseName:@"active-defers-blocks"
              reason:@"Active touch tracker ran pending work before touches ended"];

    touch.testPhase = UITouchPhaseEnded;
    [tracker noteTouchEvent:event];
    [LATestEnvironment waitForMainQueue];
    [recorder expect:!tracker.touchActive && pendingCount == 2
            caseName:@"touch-ended-drains-blocks"
              reason:@"Touch ended did not drain all pending work"];

    LATouchActivityTracker *cancelTracker = [[LATouchActivityTracker alloc] init];
    LATestTouch *cancelledTouch = [[LATestTouch alloc] init];
    LATestTouchEvent *cancelEvent = [[LATestTouchEvent alloc] init];
    cancelEvent.testTouches = [NSSet setWithObject:cancelledTouch];
    cancelledTouch.testPhase = UITouchPhaseBegan;
    [cancelTracker noteTouchEvent:cancelEvent];
    __block NSInteger cancelCount = 0;
    [cancelTracker performWhenTouchesEnd:^{
        cancelCount += 1;
    }];
    cancelledTouch.testPhase = UITouchPhaseCancelled;
    [cancelTracker noteTouchEvent:cancelEvent];
    [LATestEnvironment waitForMainQueue];
    [recorder expect:!cancelTracker.touchActive && cancelCount == 1
            caseName:@"touch-cancel-drains-blocks"
              reason:@"Touch cancellation did not drain pending work"];
}

@end
