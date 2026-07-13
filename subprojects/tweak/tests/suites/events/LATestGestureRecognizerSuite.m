//
//  LATestGestureRecognizerSuite.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestGestureRecognizerSuite.h"

#import "LATEdgeGestureClassifier.h"
#import "LATMultiTouchGestureRecognizer.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>

@implementation LATestGestureRecognizerSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"GestureRecognizer"];

    [self runEdgeGestureClassifierTestsWithRecorder:recorder];
    [self runMultiTouchGestureRecognizerTestsWithRecorder:recorder];
}

+ (void)runEdgeGestureClassifierTestsWithRecorder:(LATestRecorder *)recorder {
    LATEdgeGestureClassifier *classifier = [[LATEdgeGestureClassifier alloc] init];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);
    NSArray<NSDictionary<NSString *, id> *> *cases = @[
        @{
            @"Case" : @"edge-gesture-classifies-top-left",
            @"EventName" : LAEventNameSlideInFromTopLeft,
            @"Start" : @[ [self edgeGesturePointWithX:40.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:40.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-top",
            @"EventName" : LAEventNameStatusBarSwipeDown,
            @"Start" : @[ [self edgeGesturePointWithX:200.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:200.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-top-right",
            @"EventName" : LAEventNameSlideInFromTopRight,
            @"Start" : @[ [self edgeGesturePointWithX:360.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:360.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-bottom-left",
            @"EventName" : LAEventNameSlideInFromBottomLeft,
            @"Start" : @[ [self edgeGesturePointWithX:40.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:40.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-bottom",
            @"EventName" : LAEventNameSlideInFromBottom,
            @"Start" : @[ [self edgeGesturePointWithX:200.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:200.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-bottom-right",
            @"EventName" : LAEventNameSlideInFromBottomRight,
            @"Start" : @[ [self edgeGesturePointWithX:360.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:360.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-left-top",
            @"EventName" : LAEventNameSlideInFromLeftTop,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:80.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-left",
            @"EventName" : LAEventNameSlideInFromLeft,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:400.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:400.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-left-bottom",
            @"EventName" : LAEventNameSlideInFromLeftBottom,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:720.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:720.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-right-top",
            @"EventName" : LAEventNameSlideInFromRightTop,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:80.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-right",
            @"EventName" : LAEventNameSlideInFromRight,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:400.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:400.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-right-bottom",
            @"EventName" : LAEventNameSlideInFromRightBottom,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:720.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:720.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-top-left",
            @"EventName" : LAEventNameTwoFingerSlideInFromTopLeft,
            @"Start" : @[ [self edgeGesturePointWithX:36.0 y:2.0], [self edgeGesturePointWithX:44.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:36.0 y:80.0], [self edgeGesturePointWithX:44.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-top",
            @"EventName" : LAEventNameTwoFingerSlideInFromTop,
            @"Start" : @[ [self edgeGesturePointWithX:196.0 y:2.0], [self edgeGesturePointWithX:204.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:196.0 y:80.0], [self edgeGesturePointWithX:204.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-top-right",
            @"EventName" : LAEventNameTwoFingerSlideInFromTopRight,
            @"Start" : @[ [self edgeGesturePointWithX:356.0 y:2.0], [self edgeGesturePointWithX:364.0 y:2.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:356.0 y:80.0], [self edgeGesturePointWithX:364.0 y:80.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-bottom-left",
            @"EventName" : LAEventNameTwoFingerSlideInFromBottomLeft,
            @"Start" : @[ [self edgeGesturePointWithX:36.0 y:798.0], [self edgeGesturePointWithX:44.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:36.0 y:700.0], [self edgeGesturePointWithX:44.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-bottom",
            @"EventName" : LAEventNameTwoFingerSlideInFromBottom,
            @"Start" : @[ [self edgeGesturePointWithX:196.0 y:798.0], [self edgeGesturePointWithX:204.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:196.0 y:700.0], [self edgeGesturePointWithX:204.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-bottom-right",
            @"EventName" : LAEventNameTwoFingerSlideInFromBottomRight,
            @"Start" : @[ [self edgeGesturePointWithX:356.0 y:798.0], [self edgeGesturePointWithX:364.0 y:798.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:356.0 y:700.0], [self edgeGesturePointWithX:364.0 y:700.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-left-top",
            @"EventName" : LAEventNameTwoFingerSlideInFromLeftTop,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:76.0], [self edgeGesturePointWithX:2.0 y:84.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:76.0], [self edgeGesturePointWithX:80.0 y:84.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-left",
            @"EventName" : LAEventNameTwoFingerSlideInFromLeft,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:396.0], [self edgeGesturePointWithX:2.0 y:404.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:396.0], [self edgeGesturePointWithX:80.0 y:404.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-left-bottom",
            @"EventName" : LAEventNameTwoFingerSlideInFromLeftBottom,
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:716.0], [self edgeGesturePointWithX:2.0 y:724.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:716.0], [self edgeGesturePointWithX:80.0 y:724.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-right-top",
            @"EventName" : LAEventNameTwoFingerSlideInFromRightTop,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:76.0], [self edgeGesturePointWithX:398.0 y:84.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:76.0], [self edgeGesturePointWithX:300.0 y:84.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-right",
            @"EventName" : LAEventNameTwoFingerSlideInFromRight,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:396.0], [self edgeGesturePointWithX:398.0 y:404.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:396.0], [self edgeGesturePointWithX:300.0 y:404.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-right-bottom",
            @"EventName" : LAEventNameTwoFingerSlideInFromRightBottom,
            @"Start" : @[ [self edgeGesturePointWithX:398.0 y:716.0], [self edgeGesturePointWithX:398.0 y:724.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:300.0 y:716.0], [self edgeGesturePointWithX:300.0 y:724.0] ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in cases) {
        NSString *eventName = [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                                          bounds:bounds
                                                                  startLocations:testCase[@"Start"]
                                                                   moveLocations:testCase[@"Move"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSArray<NSDictionary<NSString *, id> *> *dragAlongCases = @[
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-bottom-left-to-right",
            @"EventName" : LAEventScreenBottomSwipeRight,
            @"Start" : @[ [self edgeGesturePointWithX:120.0 y:788.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:160.0 y:788.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-bottom-right-to-left",
            @"EventName" : LAEventScreenBottomSwipeLeft,
            @"Start" : @[ [self edgeGesturePointWithX:280.0 y:788.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:240.0 y:788.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-left-top-to-bottom",
            @"EventName" : LAEventScreenLeftSwipeDown,
            @"Start" : @[ [self edgeGesturePointWithX:10.0 y:300.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:10.0 y:340.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-left-bottom-to-top",
            @"EventName" : LAEventScreenLeftSwipeUp,
            @"Start" : @[ [self edgeGesturePointWithX:10.0 y:500.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:10.0 y:460.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-right-top-to-bottom",
            @"EventName" : LAEventScreenRightSwipeDown,
            @"Start" : @[ [self edgeGesturePointWithX:390.0 y:300.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:390.0 y:340.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-along-right-bottom-to-top",
            @"EventName" : LAEventScreenRightSwipeUp,
            @"Start" : @[ [self edgeGesturePointWithX:390.0 y:500.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:390.0 y:460.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-bottom-left-corner-horizontal-drag",
            @"EventName" : LAEventScreenBottomSwipeRight,
            @"Start" : @[ [self edgeGesturePointWithX:10.0 y:788.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:50.0 y:788.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-bottom-left-corner-vertical-drag",
            @"EventName" : LAEventScreenLeftSwipeUp,
            @"Start" : @[ [self edgeGesturePointWithX:10.0 y:788.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:10.0 y:748.0] ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in dragAlongCases) {
        NSString *eventName = [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                                          bounds:bounds
                                                                  startLocations:testCase[@"Start"]
                                                                   moveLocations:testCase[@"Move"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSString *dragMovedAwayEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:120.0 y:788.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:160.0 y:760.0] ]];
    NSString *twoFingerDragEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[
                                                [self edgeGesturePointWithX:116.0 y:788.0],
                                                [self edgeGesturePointWithX:124.0 y:788.0],
                                            ]
                                             moveLocations:@[
                                                 [self edgeGesturePointWithX:156.0 y:788.0],
                                                 [self edgeGesturePointWithX:164.0 y:788.0],
                                             ]];
    [recorder expect:dragMovedAwayEventName == nil && twoFingerDragEventName == nil
            caseName:@"edge-gesture-ignores-invalid-drag-along"
              reason:@"Drag-along classified after leaving the edge band or using multiple touches"];

    NSArray<NSDictionary<NSString *, id> *> *dragOffCases = @[
        @{
            @"Case" : @"edge-gesture-classifies-drag-off-left",
            @"EventName" : LAEventNameDragOffLeft,
            @"Move" : @[ [self edgeGesturePointWithX:10.0 y:400.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-off-right",
            @"EventName" : LAEventNameDragOffRight,
            @"Move" : @[ [self edgeGesturePointWithX:390.0 y:400.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-off-top",
            @"EventName" : LAEventNameDragOffTop,
            @"Move" : @[ [self edgeGesturePointWithX:200.0 y:10.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-drag-off-bottom",
            @"EventName" : LAEventNameDragOffBottom,
            @"Move" : @[ [self edgeGesturePointWithX:200.0 y:790.0] ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in dragOffCases) {
        NSString *eventName = [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                                          bounds:bounds
                                                                  startLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                              y:400.0] ]
                                                                   moveLocations:testCase[@"Move"]
                                                                       movePhase:3];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSString *dragOffMovedEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:10.0 y:400.0] ]
                                                 movePhase:1];
    NSString *dragOffCancelledEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:10.0 y:400.0] ]
                                                 movePhase:4];
    NSString *dragOffCornerEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:10.0 y:10.0] ]
                                                 movePhase:3];
    [recorder expect:dragOffMovedEventName == nil && dragOffCancelledEventName == nil && dragOffCornerEventName == nil
            caseName:@"edge-gesture-ignores-invalid-drag-off"
              reason:@"Drag-off classified before end, after cancellation, or from a corner endpoint"];

    NSString *nonEdgeEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:2.0 y:400.0] ]];
    [recorder expect:nonEdgeEventName == nil
            caseName:@"edge-gesture-ignores-non-edge-start"
              reason:@"A gesture that began away from the edge was classified after moving to the edge"];

    CGRect deviceBounds = CGRectMake(0.0, 0.0, 414.0, 736.0);
    NSString *wideSingleFingerLeftEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:13.0 y:368.3] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:74.0 y:368.3] ]];
    NSString *wideSingleFingerRightEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:400.0 y:368.3] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:345.0 y:368.3] ]];
    NSString *wideTwoFingerLeftEventName = [self
        classifiedEdgeGestureEventNameWithClassifier:classifier
                                              bounds:deviceBounds
                                      startLocations:@[
                                          [self edgeGesturePointWithX:26.0 y:323.0], [self edgeGesturePointWithX:26.0
                                                                                                               y:413.7]
                                      ]
                                       moveLocations:@[
                                           [self edgeGesturePointWithX:74.0 y:323.0], [self edgeGesturePointWithX:74.0
                                                                                                                y:413.7]
                                       ]];
    NSString *wideTwoFingerRightEventName = [self
        classifiedEdgeGestureEventNameWithClassifier:classifier
                                              bounds:deviceBounds
                                      startLocations:@[
                                          [self edgeGesturePointWithX:388.0 y:323.0], [self edgeGesturePointWithX:387.0
                                                                                                                y:413.7]
                                      ]
                                       moveLocations:@[
                                           [self edgeGesturePointWithX:340.0 y:323.0],
                                           [self edgeGesturePointWithX:340.0 y:413.7]
                                       ]];
    [recorder expect:wideSingleFingerLeftEventName == nil && wideSingleFingerRightEventName == nil &&
                     wideTwoFingerLeftEventName == nil && wideTwoFingerRightEventName == nil
            caseName:@"edge-gesture-keeps-side-edge-bands-narrow"
              reason:@"Side slide-in gestures classified outside their configured edge bands"];

    NSString *shortMoveEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:798.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:200.0 y:750.0] ]];
    [recorder expect:shortMoveEventName == nil
            caseName:@"edge-gesture-ignores-short-move"
              reason:@"A gesture that did not cross the interior trigger distance was classified"];

    [classifier reset];
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0
                                                                                                              y:798.0] ]
                                                                           phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    NSString *firstEventName = [classifier
        updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:700.0] ]
                                                                   phase:1]
                          bounds:bounds
                       timestamp:0.1];
    NSString *secondEventName = [classifier
        updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:650.0] ]
                                                                   phase:1]
                          bounds:bounds
                       timestamp:0.2];
    [recorder expect:[firstEventName isEqualToString:LAEventNameSlideInFromBottom] && secondEventName == nil
            caseName:@"edge-gesture-classifies-once-per-session"
              reason:@"A single edge gesture session did not classify exactly once"];

    [classifier reset];
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:120.0
                                                                                                              y:788.0] ]
                                                                           phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    NSString *firstDragEventName = [classifier
        updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:160.0 y:788.0] ]
                                                                   phase:1]
                          bounds:bounds
                       timestamp:0.1];
    NSString *secondDragEventName = [classifier
        updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:788.0] ]
                                                                   phase:1]
                          bounds:bounds
                       timestamp:0.2];
    [recorder expect:[firstDragEventName isEqualToString:LAEventScreenBottomSwipeRight] && secondDragEventName == nil
            caseName:@"edge-gesture-classifies-drag-along-once-per-session"
              reason:@"A single drag-along gesture session did not classify exactly once"];

    CGRect landscapeBounds = CGRectMake(0.0, 0.0, 812.0, 375.0);
    NSString *landscapeEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:landscapeBounds
                                            startLocations:@[ [self edgeGesturePointWithX:406.0 y:373.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:406.0 y:300.0] ]];
    [recorder expect:[landscapeEventName isEqualToString:LAEventNameSlideInFromBottom]
            caseName:@"edge-gesture-classifies-landscape-bottom"
              reason:@"Landscape bounds did not classify a bottom edge gesture"];
}

+ (void)runMultiTouchGestureRecognizerTestsWithRecorder:(LATestRecorder *)recorder {
    LATMultiTouchGestureRecognizer *recognizer = [[LATMultiTouchGestureRecognizer alloc] init];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);
    NSArray<NSDictionary<NSString *, id> *> *movementCases = @[
        @{
            @"Case" : @"multi-touch-classifies-three-finger-pinch",
            @"EventName" : LAEventNameThreeFingerPinch,
            @"Start" : @[
                [self multiTouchPointWithX:100.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:300.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:130.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:270.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-three-finger-spread",
            @"EventName" : LAEventNameThreeFingerSpread,
            @"Start" : @[
                [self multiTouchPointWithX:100.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:300.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:50.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:350.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-four-finger-pinch",
            @"EventName" : LAEventNameFourFingerPinch,
            @"Start" : @[
                [self multiTouchPointWithX:80.0 y:200.0],
                [self multiTouchPointWithX:160.0 y:200.0],
                [self multiTouchPointWithX:240.0 y:200.0],
                [self multiTouchPointWithX:320.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:116.0 y:200.0],
                [self multiTouchPointWithX:172.0 y:200.0],
                [self multiTouchPointWithX:228.0 y:200.0],
                [self multiTouchPointWithX:284.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-four-finger-spread",
            @"EventName" : LAEventNameFourFingerSpread,
            @"Start" : @[
                [self multiTouchPointWithX:80.0 y:200.0],
                [self multiTouchPointWithX:160.0 y:200.0],
                [self multiTouchPointWithX:240.0 y:200.0],
                [self multiTouchPointWithX:320.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:20.0 y:200.0],
                [self multiTouchPointWithX:140.0 y:200.0],
                [self multiTouchPointWithX:260.0 y:200.0],
                [self multiTouchPointWithX:380.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-five-finger-pinch",
            @"EventName" : LAEventNameFiveFingerPinch,
            @"Start" : @[
                [self multiTouchPointWithX:50.0 y:200.0],
                [self multiTouchPointWithX:125.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:275.0 y:200.0],
                [self multiTouchPointWithX:350.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:80.0 y:200.0],
                [self multiTouchPointWithX:140.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:260.0 y:200.0],
                [self multiTouchPointWithX:320.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-five-finger-spread",
            @"EventName" : LAEventNameFiveFingerSpread,
            @"Start" : @[
                [self multiTouchPointWithX:50.0 y:200.0],
                [self multiTouchPointWithX:125.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:275.0 y:200.0],
                [self multiTouchPointWithX:350.0 y:200.0],
            ],
            @"Move" : @[
                [self multiTouchPointWithX:0.0 y:200.0],
                [self multiTouchPointWithX:100.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:300.0 y:200.0],
                [self multiTouchPointWithX:400.0 y:200.0],
            ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in movementCases) {
        NSString *eventName = [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                                         bounds:bounds
                                                                 startLocations:testCase[@"Start"]
                                                                  moveLocations:testCase[@"Move"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSArray<NSDictionary<NSString *, id> *> *tapCases = @[
        @{
            @"Case" : @"multi-touch-classifies-three-finger-tap",
            @"EventName" : LAEventNameThreeFingerTap,
            @"Locations" : @[
                [self multiTouchPointWithX:100.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:300.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-four-finger-tap",
            @"EventName" : LAEventNameFourFingerTap,
            @"Locations" : @[
                [self multiTouchPointWithX:80.0 y:200.0],
                [self multiTouchPointWithX:160.0 y:200.0],
                [self multiTouchPointWithX:240.0 y:200.0],
                [self multiTouchPointWithX:320.0 y:200.0],
            ],
        },
        @{
            @"Case" : @"multi-touch-classifies-five-finger-tap",
            @"EventName" : LAEventNameFiveFingerTap,
            @"Locations" : @[
                [self multiTouchPointWithX:50.0 y:200.0],
                [self multiTouchPointWithX:125.0 y:200.0],
                [self multiTouchPointWithX:200.0 y:200.0],
                [self multiTouchPointWithX:275.0 y:200.0],
                [self multiTouchPointWithX:350.0 y:200.0],
            ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in tapCases) {
        NSString *eventName = [self classifiedMultiTouchTapEventNameWithRecognizer:recognizer
                                                                            bounds:bounds
                                                                    startLocations:testCase[@"Locations"]
                                                                      endLocations:testCase[@"Locations"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSString *twoFingerEventName = [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                                              bounds:bounds
                                                                      startLocations:@[
                                                                          [self multiTouchPointWithX:100.0 y:200.0],
                                                                          [self multiTouchPointWithX:300.0 y:200.0],
                                                                      ]
                                                                       moveLocations:@[
                                                                           [self multiTouchPointWithX:150.0 y:200.0],
                                                                           [self multiTouchPointWithX:250.0 y:200.0],
                                                                       ]];
    [recorder expect:twoFingerEventName == nil
            caseName:@"multi-touch-ignores-two-finger-session"
              reason:@"Two-finger movement was classified as a multi-touch Activator event"];

    NSString *sixFingerEventName = [self classifiedMultiTouchEventNameWithRecognizer:recognizer
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
    [recorder expect:sixFingerEventName == nil
            caseName:@"multi-touch-ignores-six-finger-session"
              reason:@"Six-finger movement was classified as a multi-touch Activator event"];

    [recognizer reset];
    [recognizer la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                             phase:UITouchPhaseBegan
                                            bounds:bounds
                                         timestamp:0.0];
    NSString *cancelledEventName = [recognizer la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                                                            phase:UITouchPhaseCancelled
                                                                           bounds:bounds
                                                                        timestamp:0.1];
    [recorder expect:cancelledEventName == nil && ![recognizer la_testingHasRecognitionState]
            caseName:@"multi-touch-cancel-resets-session"
              reason:@"Cancelled multi-touch session dispatched or kept recognition state"];

    [recognizer reset];
    [recognizer la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:300.0 y:200.0],
    ]
                                             phase:UITouchPhaseBegan
                                            bounds:bounds
                                         timestamp:0.0];
    NSString *firstPinchEventName = [recognizer la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:130.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:270.0 y:200.0],
    ]
                                                                             phase:UITouchPhaseMoved
                                                                            bounds:bounds
                                                                         timestamp:0.1];
    NSString *secondPinchEventName = [recognizer la_testingUpdateWithTouchLocations:@[
        [self multiTouchPointWithX:140.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
        [self multiTouchPointWithX:260.0 y:200.0],
    ]
                                                                              phase:UITouchPhaseMoved
                                                                             bounds:bounds
                                                                          timestamp:0.2];
    [recorder expect:[firstPinchEventName isEqualToString:LAEventNameThreeFingerPinch] && secondPinchEventName == nil
            caseName:@"multi-touch-classifies-once-per-session"
              reason:@"A single multi-touch session did not classify exactly once"];

    NSArray<NSValue *> *thresholdStartLocations = @[
        [self multiTouchPointWithX:0.0 y:200.0],
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
    ];
    NSString *pinchAboveThresholdEventName =
        [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                   bounds:bounds
                                           startLocations:thresholdStartLocations
                                            moveLocations:@[
                                                [self multiTouchPointWithX:0.0 y:200.0],
                                                [self multiTouchPointWithX:86.61 y:200.0],
                                                [self multiTouchPointWithX:173.22 y:200.0],
                                            ]];
    NSString *pinchBelowThresholdEventName =
        [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                   bounds:bounds
                                           startLocations:thresholdStartLocations
                                            moveLocations:@[
                                                [self multiTouchPointWithX:0.0 y:200.0],
                                                [self multiTouchPointWithX:86.59 y:200.0],
                                                [self multiTouchPointWithX:173.18 y:200.0],
                                            ]];
    [recorder expect:pinchAboveThresholdEventName == nil &&
                     [pinchBelowThresholdEventName isEqualToString:LAEventNameThreeFingerPinch]
            caseName:@"multi-touch-pinch-threshold-is-strict"
              reason:@"Pinch classification did not stay on the legacy strict threshold"];

    NSString *spreadBelowThresholdEventName =
        [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                   bounds:bounds
                                           startLocations:thresholdStartLocations
                                            moveLocations:@[
                                                [self multiTouchPointWithX:0.0 y:200.0],
                                                [self multiTouchPointWithX:115.46 y:200.0],
                                                [self multiTouchPointWithX:230.92 y:200.0],
                                            ]];
    NSString *spreadAboveThresholdEventName =
        [self classifiedMultiTouchEventNameWithRecognizer:recognizer
                                                   bounds:bounds
                                           startLocations:thresholdStartLocations
                                            moveLocations:@[
                                                [self multiTouchPointWithX:0.0 y:200.0],
                                                [self multiTouchPointWithX:115.48 y:200.0],
                                                [self multiTouchPointWithX:230.96 y:200.0],
                                            ]];
    [recorder expect:spreadBelowThresholdEventName == nil &&
                     [spreadAboveThresholdEventName isEqualToString:LAEventNameThreeFingerSpread]
            caseName:@"multi-touch-spread-threshold-is-strict"
              reason:@"Spread classification did not stay on the legacy strict threshold"];

    NSArray<NSValue *> *tapStartLocations = @[
        [self multiTouchPointWithX:0.0 y:200.0],
        [self multiTouchPointWithX:100.0 y:200.0],
        [self multiTouchPointWithX:200.0 y:200.0],
    ];
    NSString *tapBelowMovementLimitEventName =
        [self classifiedMultiTouchTapEventNameWithRecognizer:recognizer
                                                      bounds:bounds
                                              startLocations:tapStartLocations
                                                endLocations:@[
                                                    [self multiTouchPointWithX:9.0 y:200.0],
                                                    [self multiTouchPointWithX:100.0 y:200.0],
                                                    [self multiTouchPointWithX:200.0 y:200.0],
                                                ]];
    NSString *tapAtMovementLimitEventName =
        [self classifiedMultiTouchTapEventNameWithRecognizer:recognizer
                                                      bounds:bounds
                                              startLocations:tapStartLocations
                                                endLocations:@[
                                                    [self multiTouchPointWithX:10.0 y:200.0],
                                                    [self multiTouchPointWithX:100.0 y:200.0],
                                                    [self multiTouchPointWithX:200.0 y:200.0],
                                                ]];
    [recorder expect:[tapBelowMovementLimitEventName isEqualToString:LAEventNameThreeFingerTap] &&
                     tapAtMovementLimitEventName == nil
            caseName:@"multi-touch-tap-movement-limit-is-strict"
              reason:@"Tap classification did not stay below the legacy movement limit"];
}

+ (NSString *)classifiedMultiTouchEventNameWithRecognizer:(LATMultiTouchGestureRecognizer *)recognizer
                                                   bounds:(CGRect)bounds
                                           startLocations:(NSArray<NSValue *> *)startLocations
                                            moveLocations:(NSArray<NSValue *> *)moveLocations {
    [recognizer reset];
    [recognizer la_testingUpdateWithTouchLocations:startLocations phase:UITouchPhaseBegan bounds:bounds timestamp:0.0];
    return [recognizer la_testingUpdateWithTouchLocations:moveLocations
                                                    phase:UITouchPhaseMoved
                                                   bounds:bounds
                                                timestamp:0.1];
}

+ (NSString *)classifiedMultiTouchTapEventNameWithRecognizer:(LATMultiTouchGestureRecognizer *)recognizer
                                                      bounds:(CGRect)bounds
                                              startLocations:(NSArray<NSValue *> *)startLocations
                                                endLocations:(NSArray<NSValue *> *)endLocations {
    [recognizer reset];
    [recognizer la_testingUpdateWithTouchLocations:startLocations phase:UITouchPhaseBegan bounds:bounds timestamp:0.0];
    return [recognizer la_testingUpdateWithTouchLocations:endLocations
                                                    phase:UITouchPhaseEnded
                                                   bounds:bounds
                                                timestamp:0.1];
}

+ (NSString *)classifiedEdgeGestureEventNameWithClassifier:(LATEdgeGestureClassifier *)classifier
                                                    bounds:(CGRect)bounds
                                            startLocations:(NSArray<NSValue *> *)startLocations
                                             moveLocations:(NSArray<NSValue *> *)moveLocations {
    return [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                       bounds:bounds
                                               startLocations:startLocations
                                                moveLocations:moveLocations
                                                    movePhase:1];
}

+ (NSString *)classifiedEdgeGestureEventNameWithClassifier:(LATEdgeGestureClassifier *)classifier
                                                    bounds:(CGRect)bounds
                                            startLocations:(NSArray<NSValue *> *)startLocations
                                             moveLocations:(NSArray<NSValue *> *)moveLocations
                                                 movePhase:(NSInteger)movePhase {
    [classifier reset];
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:startLocations phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    return [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:moveLocations phase:movePhase]
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

@end
