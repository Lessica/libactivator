//
//  LAConstants.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Activator/Activator.h>

NSString *const LAEventModeSpringBoard = @"springboard";
NSString *const LAEventModeApplication = @"application";
NSString *const LAEventModeLockScreen = @"lockscreen";

NSString *const LAActivatorAvailableListenersChangedNotification = @"libactivator.listeners.changed";
NSString *const LAActivatorAvailableEventsChangedNotification = @"libactivator.events.changed";
NSString *const LAActivatorAssignmentsChangedNotification = @"libactivator.assignments.changed";
NSString *const LAActivatorEventModeChangedNotification = @"libactivator.eventmode.changed";
NSString *const LAActivatorAuthorizationChangedNotification = @"libactivator.authorization.changed";
NSString *const LAActivatorListenerRegistryChangedNotification = @"LAActivatorListenerRegistryChangedNotification";
NSString *const LAActivatorEventRegistryChangedNotification = @"LAActivatorEventRegistryChangedNotification";

NSString *const LAEventNameMenuPressSingle = @"libactivator.menu.press.single";
NSString *const LAEventNameMenuPressDouble = @"libactivator.menu.press.double";
NSString *const LAEventNameMenuPressTriple = @"libactivator.menu.press.triple";
NSString *const LAEventNameMenuHoldShort = @"libactivator.menu.hold.short";
NSString *const LAEventNameMenuHoldLong = @"libactivator.menu.hold.long";
__attribute__((visibility("default"))) NSString *const LAEventNameMenuPressAtSpringBoard =
    @"libactivator.menu.press.at-springboard";

NSString *const LAEventNameLockHoldShort = @"libactivator.lock.hold.short";
NSString *const LAEventNameLockHoldLong = @"libactivator.lock.hold.long";
NSString *const LAEventNameLockPressDouble = @"libactivator.lock.press.double";
NSString *const LAEventNameLockPressTriple = @"libactivator.lock.press.triple";
NSString *const LAEventNameLockPressWithMenu = @"libactivator.lock.press.with-menu";

NSString *const LAEventNameSpringBoardPinch = @"libactivator.springboard.pinch";
NSString *const LAEventNameSpringBoardSpread = @"libactivator.springboard.spread";

NSString *const LAEventNameStatusBarSwipeRight = @"libactivator.statusbar.swipe.right";
NSString *const LAEventNameStatusBarSwipeLeft = @"libactivator.statusbar.swipe.left";
NSString *const LAEventNameStatusBarTapDouble = @"libactivator.statusbar.tap.double";
NSString *const LAEventNameStatusBarTapDoubleLeft = @"libactivator.statusbar.tap.double.left";
NSString *const LAEventNameStatusBarTapDoubleRight = @"libactivator.statusbar.tap.double.right";
NSString *const LAEventNameStatusBarTapSingle = @"libactivator.statusbar.tap.single";
NSString *const LAEventNameStatusBarTapSingleLeft = @"libactivator.statusbar.tap.single.left";
NSString *const LAEventNameStatusBarTapSingleRight = @"libactivator.statusbar.tap.single.right";
NSString *const LAEventNameStatusBarHold = @"libactivator.statusbar.hold";
NSString *const LAEventNameStatusBarHoldLeft = @"libactivator.statusbar.hold.left";
NSString *const LAEventNameStatusBarHoldRight = @"libactivator.statusbar.hold.right";

NSString *const LAEventNameVolumeDownUp = @"libactivator.volume.down-up";
NSString *const LAEventNameVolumeUpDown = @"libactivator.volume.up-down";
NSString *const LAEventNameVolumeDisplayTap = @"libactivator.volume.display-tap";
NSString *const LAEventNameVolumeToggleMuteTwice = @"libactivator.volume.toggle-mute-twice";
NSString *const LAEventNameVolumeMuteOn = @"libactivator.volume.mute";
NSString *const LAEventNameVolumeMuteOff = @"libactivator.volume.unmute";
NSString *const LAEventNameVolumeDownHoldShort = @"libactivator.volume.down.hold.short";
NSString *const LAEventNameVolumeUpHoldShort = @"libactivator.volume.up.hold.short";
NSString *const LAEventNameVolumeDownPress = @"libactivator.volume.down.press";
NSString *const LAEventNameVolumeUpPress = @"libactivator.volume.up.press";
NSString *const LAEventNameVolumeBothPress = @"libactivator.volume.both.press";
NSString *const LAEventNameVolumeDownPressWithMenu = @"libactivator.volume.down.press.with-menu";
NSString *const LAEventNameVolumeUpPressWithMenu = @"libactivator.volume.up.press.with-menu";

NSString *const LAEventNameSlideInFromBottom = @"libactivator.slide-in.bottom";
NSString *const LAEventNameSlideInFromBottomLeft = @"libactivator.slide-in.bottom-left";
NSString *const LAEventNameSlideInFromBottomRight = @"libactivator.slide-in.bottom-right";
NSString *const LAEventNameSlideInFromLeft = @"libactivator.slide-in.left";
NSString *const LAEventNameSlideInFromLeftTop = @"libactivator.slide-in.left-top";
NSString *const LAEventNameSlideInFromLeftBottom = @"libactivator.slide-in.left-bottom";
NSString *const LAEventNameSlideInFromRight = @"libactivator.slide-in.right";
NSString *const LAEventNameSlideInFromRightTop = @"libactivator.slide-in.right-top";
NSString *const LAEventNameSlideInFromRightBottom = @"libactivator.slide-in.right-bottom";
NSString *const LAEventNameStatusBarSwipeDown = @"libactivator.statusbar.swipe.down";
NSString *const LAEventNameSlideInFromTopLeft = @"libactivator.slide-in.top-left";
NSString *const LAEventNameSlideInFromTopRight = @"libactivator.slide-in.top-right";

NSString *const LAEventNameTwoFingerSlideInFromBottom = @"libactivator.two-finger-slide-in.bottom";
NSString *const LAEventNameTwoFingerSlideInFromBottomLeft = @"libactivator.two-finger-slide-in.bottom-left";
NSString *const LAEventNameTwoFingerSlideInFromBottomRight = @"libactivator.two-finger-slide-in.bottom-right";
NSString *const LAEventNameTwoFingerSlideInFromLeft = @"libactivator.two-finger-slide-in.left";
NSString *const LAEventNameTwoFingerSlideInFromLeftTop = @"libactivator.two-finger-slide-in.left-top";
NSString *const LAEventNameTwoFingerSlideInFromLeftBottom = @"libactivator.two-finger-slide-in.left-bottom";
NSString *const LAEventNameTwoFingerSlideInFromRight = @"libactivator.two-finger-slide-in.right";
NSString *const LAEventNameTwoFingerSlideInFromRightTop = @"libactivator.two-finger-slide-in.right-top";
NSString *const LAEventNameTwoFingerSlideInFromRightBottom = @"libactivator.two-finger-slide-in.right-bottom";
NSString *const LAEventNameTwoFingerSlideInFromTop = @"libactivator.two-finger-slide-in.top";
NSString *const LAEventNameTwoFingerSlideInFromTopLeft = @"libactivator.two-finger-slide-in.top-left";
NSString *const LAEventNameTwoFingerSlideInFromTopRight = @"libactivator.two-finger-slide-in.top-right";

NSString *const LAEventNameDragOffBottom = @"libactivator.drag-off.bottom";
NSString *const LAEventNameDragOffLeft = @"libactivator.drag-off.left";
NSString *const LAEventNameDragOffRight = @"libactivator.drag-off.right";
NSString *const LAEventNameDragOffTop = @"libactivator.drag-off.top";

NSString *const LAEventScreenBottomSwipeLeft = @"libactivator.drag-along.screen-bottom.right-to-left";
NSString *const LAEventScreenBottomSwipeRight = @"libactivator.drag-along.screen-bottom.left-to-right";
NSString *const LAEventScreenLeftSwipeDown = @"libactivator.drag-along.screen-left.top-to-bottom";
NSString *const LAEventScreenLeftSwipeUp = @"libactivator.drag-along.screen-left.bottom-to-top";
NSString *const LAEventScreenRightSwipeDown = @"libactivator.drag-along.screen-right.top-to-bottom";
NSString *const LAEventScreenRightSwipeUp = @"libactivator.drag-along.screen-right.bottom-to-top";

NSString *const LAEventNameForceTouchStatusBar = @"libactivator.force-touch.statusbar";
NSString *const LAEventNameForceTouchScreenLeft = @"libactivator.force-touch.screen-left";
NSString *const LAEventNameForceTouchScreenRight = @"libactivator.force-touch.screen-right";
NSString *const LAEventNameForceTouchScreenBottomLeft = @"libactivator.force-touch.screen-bottom-left";
NSString *const LAEventNameForceTouchScreenBottom = @"libactivator.force-touch.screen-bottom";
NSString *const LAEventNameForceTouchScreenBottomRight = @"libactivator.force-touch.screen-bottom-right";

NSString *const LAEventNameMotionShake = @"libactivator.motion.shake";

NSString *const LAEventNameHeadsetButtonPressSingle = @"libactivator.headset-button.press.single";
NSString *const LAEventNameHeadsetButtonHoldShort = @"libactivator.headset-button.hold.short";
NSString *const LAEventNameHeadsetConnected = @"libactivator.headset.connected";
NSString *const LAEventNameHeadsetDisconnected = @"libactivator.headset.disconnected";

NSString *const LAEventNameGestureBarTapDouble = @"libactivator.gesture-bar.double-tap";

NSString *const LAEventNameLockScreenClockDoubleTap = @"libactivator.lockscreen.clock.double-tap";
NSString *const LAEventNameLockScreenClockTapHold = @"libactivator.lockscreen.clock.tap-hold";
NSString *const LAEventNameLockScreenClockSwipeLeft = @"libactivator.lockscreen.clock.swipe-left";
NSString *const LAEventNameLockScreenClockSwipeRight = @"libactivator.lockscreen.clock.swipe-right";
NSString *const LAEventNameLockScreenClockSwipeDown = @"libactivator.lockscreen.clock.swipe-down";

NSString *const LAEventNameNowPlayingInfoChanged = @"libactivator.now-playing.info-changed";
NSString *const LAEventNameNowPlayingPlaying = @"libactivator.now-playing.playing";
NSString *const LAEventNameNowPlayingPaused = @"libactivator.now-playing.paused";

NSString *const LAEventNamePowerConnected = @"libactivator.power.connected";
NSString *const LAEventNamePowerDisconnected = @"libactivator.power.disconnected";

NSString *const LAEventNameScheduledSunrise = @"libactivator.scheduled.sunrise";
NSString *const LAEventNameScheduledSunset = @"libactivator.scheduled.sunset";

NSString *const LAEventNameThreeFingerTap = @"libactivator.three-finger.tap";
NSString *const LAEventNameThreeFingerPinch = @"libactivator.three-finger.pinch";
NSString *const LAEventNameThreeFingerSpread = @"libactivator.three-finger.spread";

NSString *const LAEventNameFourFingerTap = @"libactivator.four-finger.tap";
NSString *const LAEventNameFourFingerPinch = @"libactivator.four-finger.pinch";
NSString *const LAEventNameFourFingerSpread = @"libactivator.four-finger.spread";

NSString *const LAEventNameFiveFingerTap = @"libactivator.five-finger.tap";
NSString *const LAEventNameFiveFingerPinch = @"libactivator.five-finger.pinch";
NSString *const LAEventNameFiveFingerSpread = @"libactivator.five-finger.spread";

NSString *const LAEventNameClamshellOpen = @"libactivator.clamshell.open";
NSString *const LAEventNameClamshellClose = @"libactivator.clamshell.close";

NSString *const LAEventNameCarConnected = @"libactivator.car.connected";
NSString *const LAEventNameCarDisconnected = @"libactivator.car.disconnected";

NSString *const LAEventNameSpringBoardIconFlickUp = @"libactivator.icon.flick.up";
NSString *const LAEventNameSpringBoardIconFlickDown = @"libactivator.icon.flick.down";
NSString *const LAEventNameSpringBoardIconFlickLeft = @"libactivator.icon.flick.left";
NSString *const LAEventNameSpringBoardIconFlickRight = @"libactivator.icon.flick.right";
__attribute__((visibility("default"))) NSString *const LAEventNameSpringBoardIcon3DTouch =
    @"libactivator.icon.3d-touch";
__attribute__((visibility("default"))) NSString *const LAEventNameSpringBoardIconDoubleTap =
    @"libactivator.icon.tap.double";
__attribute__((visibility("default"))) NSString *const LAEventNameSpringBoardIconHold = @"libactivator.icon.hold";

NSString *const LAEventNameDeviceLocked = @"libactivator.device.locked";
NSString *const LAEventNameDeviceUnlocked = @"libactivator.device.unlocked";

NSString *const LAEventNameWatchConnected = @"libactivator.watch.connected";
NSString *const LAEventNameWatchDisconnected = @"libactivator.watch.disconnected";

NSString *const LAEventNameNetworkJoinedWiFi = @"libactivator.network.joined-wifi";
NSString *const LAEventNameNetworkLeftWiFi = @"libactivator.network.left-wifi";

NSString *const LAEventNameFingerprintSensorPressSingle = @"libactivator.fingerprint-sensor.press.single";
NSString *const LAEventNameFingerprintSensorPressTwice = @"libactivator.fingerprint-sensor.press.twice";
NSString *const LAEventNameFingerprintSensorHold = @"libactivator.fingerprint-sensor.hold";
NSString *const LAEventNameFingerprintSensorHoldLong = @"libactivator.fingerprint-sensor.hold-long";
NSString *const LAEventNameFingerprintSensorPressSingleAndSlideIn =
    @"libactivator.fingerprint-sensor.press.single.with-slide-in";
NSString *const LAEventNameFingerprintSensorPressSingleAndHold =
    @"libactivator.fingerprint-sensor.press.single.with-hold";

NSString *const LAEventUserInfoDisplayIdentifier = @"displayIdentifier";
NSString *const LAEventUserInfoIconView = @"iconView";
NSString *const LAEventUserInfoUnlockedDeviceToSendEvent = @"unlockedDeviceToSendEvent";
