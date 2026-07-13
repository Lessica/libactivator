//
//  LATestEventSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSuite.h"

#import "LATestRecorder.h"

#import <Activator/Activator.h>

@implementation LATestEventSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"LAEvent"];

    LAEvent *event = [LAEvent eventWithName:@"libactivator.test.event" mode:nil];
    event.handled = YES;
    event.userInfo = @{@"Key" : @"Value"};
    [recorder expect:[event.name isEqualToString:@"libactivator.test.event"]
            caseName:@"factory-name"
              reason:@"Name mismatch"];
    [recorder expect:event.mode == nil caseName:@"nil-mode" reason:@"Nil mode was not preserved"];
    [recorder expect:event.handled caseName:@"handled" reason:@"Handled flag mismatch"];
    [recorder expect:[event.userInfo[@"Key"] isEqualToString:@"Value"]
            caseName:@"user-info"
              reason:@"User info mismatch"];
    [recorder
          expect:[LAEventScreenBottomSwipeLeft
                     isEqualToString:@"libactivator.drag-along.screen-bottom.right-to-left"] &&
                 [LAEventScreenBottomSwipeRight
                     isEqualToString:@"libactivator.drag-along.screen-bottom.left-to-right"] &&
                 [LAEventScreenLeftSwipeDown isEqualToString:@"libactivator.drag-along.screen-left.top-to-bottom"] &&
                 [LAEventScreenLeftSwipeUp isEqualToString:@"libactivator.drag-along.screen-left.bottom-to-top"] &&
                 [LAEventScreenRightSwipeDown isEqualToString:@"libactivator.drag-along.screen-right.top-to-bottom"] &&
                 [LAEventScreenRightSwipeUp isEqualToString:@"libactivator.drag-along.screen-right.bottom-to-top"]
        caseName:@"screen-side-swipe-constant-values"
          reason:@"Screen-side swipe constants did not match the 1.9.13 drag-along event names"];

    NSDictionary<NSString *, NSString *> *resourceBackedEventConstants = @{
        @"LAEventNameCarConnected" : LAEventNameCarConnected,
        @"LAEventNameCarDisconnected" : LAEventNameCarDisconnected,
        @"LAEventNameForceTouchScreenBottom" : LAEventNameForceTouchScreenBottom,
        @"LAEventNameForceTouchScreenBottomLeft" : LAEventNameForceTouchScreenBottomLeft,
        @"LAEventNameForceTouchScreenBottomRight" : LAEventNameForceTouchScreenBottomRight,
        @"LAEventNameForceTouchScreenLeft" : LAEventNameForceTouchScreenLeft,
        @"LAEventNameForceTouchScreenRight" : LAEventNameForceTouchScreenRight,
        @"LAEventNameForceTouchStatusBar" : LAEventNameForceTouchStatusBar,
        @"LAEventNameGestureBarTapDouble" : LAEventNameGestureBarTapDouble,
        @"LAEventNameLockPressTriple" : LAEventNameLockPressTriple,
        @"LAEventNameLockScreenClockSwipeDown" : LAEventNameLockScreenClockSwipeDown,
        @"LAEventNameLockScreenClockSwipeLeft" : LAEventNameLockScreenClockSwipeLeft,
        @"LAEventNameLockScreenClockSwipeRight" : LAEventNameLockScreenClockSwipeRight,
        @"LAEventNameNowPlayingInfoChanged" : LAEventNameNowPlayingInfoChanged,
        @"LAEventNameNowPlayingPaused" : LAEventNameNowPlayingPaused,
        @"LAEventNameNowPlayingPlaying" : LAEventNameNowPlayingPlaying,
        @"LAEventNameScheduledSunrise" : LAEventNameScheduledSunrise,
        @"LAEventNameScheduledSunset" : LAEventNameScheduledSunset,
        @"LAEventNameSlideInFromLeftBottom" : LAEventNameSlideInFromLeftBottom,
        @"LAEventNameSlideInFromLeftTop" : LAEventNameSlideInFromLeftTop,
        @"LAEventNameSlideInFromRightBottom" : LAEventNameSlideInFromRightBottom,
        @"LAEventNameSlideInFromRightTop" : LAEventNameSlideInFromRightTop,
        @"LAEventNameSpringBoardIconFlickDown" : LAEventNameSpringBoardIconFlickDown,
        @"LAEventNameSpringBoardIconFlickLeft" : LAEventNameSpringBoardIconFlickLeft,
        @"LAEventNameSpringBoardIconFlickRight" : LAEventNameSpringBoardIconFlickRight,
        @"LAEventNameSpringBoardIconFlickUp" : LAEventNameSpringBoardIconFlickUp,
        @"LAEventNameTwoFingerSlideInFromLeftBottom" : LAEventNameTwoFingerSlideInFromLeftBottom,
        @"LAEventNameTwoFingerSlideInFromLeftTop" : LAEventNameTwoFingerSlideInFromLeftTop,
        @"LAEventNameTwoFingerSlideInFromRightBottom" : LAEventNameTwoFingerSlideInFromRightBottom,
        @"LAEventNameTwoFingerSlideInFromRightTop" : LAEventNameTwoFingerSlideInFromRightTop,
        @"LAEventNameWatchConnected" : LAEventNameWatchConnected,
        @"LAEventNameWatchDisconnected" : LAEventNameWatchDisconnected,
    };
    NSDictionary<NSString *, NSString *> *expectedResourceBackedEventConstants = @{
        @"LAEventNameCarConnected" : @"libactivator.car.connected",
        @"LAEventNameCarDisconnected" : @"libactivator.car.disconnected",
        @"LAEventNameForceTouchScreenBottom" : @"libactivator.force-touch.screen-bottom",
        @"LAEventNameForceTouchScreenBottomLeft" : @"libactivator.force-touch.screen-bottom-left",
        @"LAEventNameForceTouchScreenBottomRight" : @"libactivator.force-touch.screen-bottom-right",
        @"LAEventNameForceTouchScreenLeft" : @"libactivator.force-touch.screen-left",
        @"LAEventNameForceTouchScreenRight" : @"libactivator.force-touch.screen-right",
        @"LAEventNameForceTouchStatusBar" : @"libactivator.force-touch.statusbar",
        @"LAEventNameGestureBarTapDouble" : @"libactivator.gesture-bar.double-tap",
        @"LAEventNameLockPressTriple" : @"libactivator.lock.press.triple",
        @"LAEventNameLockScreenClockSwipeDown" : @"libactivator.lockscreen.clock.swipe-down",
        @"LAEventNameLockScreenClockSwipeLeft" : @"libactivator.lockscreen.clock.swipe-left",
        @"LAEventNameLockScreenClockSwipeRight" : @"libactivator.lockscreen.clock.swipe-right",
        @"LAEventNameNowPlayingInfoChanged" : @"libactivator.now-playing.info-changed",
        @"LAEventNameNowPlayingPaused" : @"libactivator.now-playing.paused",
        @"LAEventNameNowPlayingPlaying" : @"libactivator.now-playing.playing",
        @"LAEventNameScheduledSunrise" : @"libactivator.scheduled.sunrise",
        @"LAEventNameScheduledSunset" : @"libactivator.scheduled.sunset",
        @"LAEventNameSlideInFromLeftBottom" : @"libactivator.slide-in.left-bottom",
        @"LAEventNameSlideInFromLeftTop" : @"libactivator.slide-in.left-top",
        @"LAEventNameSlideInFromRightBottom" : @"libactivator.slide-in.right-bottom",
        @"LAEventNameSlideInFromRightTop" : @"libactivator.slide-in.right-top",
        @"LAEventNameSpringBoardIconFlickDown" : @"libactivator.icon.flick.down",
        @"LAEventNameSpringBoardIconFlickLeft" : @"libactivator.icon.flick.left",
        @"LAEventNameSpringBoardIconFlickRight" : @"libactivator.icon.flick.right",
        @"LAEventNameSpringBoardIconFlickUp" : @"libactivator.icon.flick.up",
        @"LAEventNameTwoFingerSlideInFromLeftBottom" : @"libactivator.two-finger-slide-in.left-bottom",
        @"LAEventNameTwoFingerSlideInFromLeftTop" : @"libactivator.two-finger-slide-in.left-top",
        @"LAEventNameTwoFingerSlideInFromRightBottom" : @"libactivator.two-finger-slide-in.right-bottom",
        @"LAEventNameTwoFingerSlideInFromRightTop" : @"libactivator.two-finger-slide-in.right-top",
        @"LAEventNameWatchConnected" : @"libactivator.watch.connected",
        @"LAEventNameWatchDisconnected" : @"libactivator.watch.disconnected",
    };
    [recorder expect:[resourceBackedEventConstants isEqualToDictionary:expectedResourceBackedEventConstants]
            caseName:@"resource-backed-event-constant-values"
              reason:@"Public event constants did not match the 1.9.13 bundled resource event names"];

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:NO error:&archiveError];
    NSError *unarchiveError = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&unarchiveError];
    unarchiver.requiresSecureCoding = NO;
    LAEvent *decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    [recorder expect:data.length > 0 && archiveError == nil && unarchiveError == nil &&
                     [decoded.name isEqualToString:event.name] && decoded.handled
            caseName:@"nscoding"
              reason:@"NSCoding round-trip failed"];
}

@end
