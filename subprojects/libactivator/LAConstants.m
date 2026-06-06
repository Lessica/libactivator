#import <Foundation/Foundation.h>

#import <Activator/Activator.h>

NSString *const LAEventModeSpringBoard = @"springboard";
NSString *const LAEventModeApplication = @"application";
NSString *const LAEventModeLockScreen = @"lockscreen";

NSString *const LAActivatorAvailableListenersChangedNotification = @"LAActivatorAvailableListenersChangedNotification";
NSString *const LAActivatorAvailableEventsChangedNotification = @"LAActivatorAvailableEventsChangedNotification";
NSString *const LAActivatorAssignmentsChangedNotification = @"LAActivatorAssignmentsChangedNotification";

NSString *const LAEventNameMenuPressSingle = @"libactivator.menu.press.single";
NSString *const LAEventNameMenuPressDouble = @"libactivator.menu.press.double";
NSString *const LAEventNameMenuPressTriple = @"libactivator.menu.press.triple";
NSString *const LAEventNameMenuHoldShort = @"libactivator.menu.hold.short";
NSString *const LAEventNameMenuHoldLong = @"libactivator.menu.hold.long";

NSString *const LAEventNameLockHoldShort = @"libactivator.lock.hold.short";
NSString *const LAEventNameLockHoldLong = @"libactivator.lock.hold.long";
NSString *const LAEventNameLockPressDouble = @"libactivator.lock.press.double";
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
NSString *const LAEventNameVolumeDownHoldShort = @"libactivator.volume.down.hold.short";
NSString *const LAEventNameVolumeUpHoldShort = @"libactivator.volume.up.hold.short";
NSString *const LAEventNameVolumeDownPress = @"libactivator.volume.down.press";
NSString *const LAEventNameVolumeUpPress = @"libactivator.volume.up.press";
NSString *const LAEventNameVolumeBothPress = @"libactivator.volume.both.press";

NSString *const LAEventNameSlideInFromBottom = @"libactivator.slide-in.bottom";
NSString *const LAEventNameSlideInFromBottomLeft = @"libactivator.slide-in.bottom-left";
NSString *const LAEventNameSlideInFromBottomRight = @"libactivator.slide-in.bottom-right";
NSString *const LAEventNameSlideInFromLeft = @"libactivator.slide-in.left";
NSString *const LAEventNameSlideInFromRight = @"libactivator.slide-in.right";
NSString *const LAEventNameStatusBarSwipeDown = @"libactivator.statusbar.swipe.down";
NSString *const LAEventNameSlideInFromTopLeft = @"libactivator.slide-in.top-left";
NSString *const LAEventNameSlideInFromTopRight = @"libactivator.slide-in.top-right";

NSString *const LAEventNameTwoFingerSlideInFromBottom = @"libactivator.two-finger-slide-in.bottom";
NSString *const LAEventNameTwoFingerSlideInFromBottomLeft = @"libactivator.two-finger-slide-in.bottom-left";
NSString *const LAEventNameTwoFingerSlideInFromBottomRight = @"libactivator.two-finger-slide-in.bottom-right";
NSString *const LAEventNameTwoFingerSlideInFromLeft = @"libactivator.two-finger-slide-in.left";
NSString *const LAEventNameTwoFingerSlideInFromRight = @"libactivator.two-finger-slide-in.right";
NSString *const LAEventNameTwoFingerSlideInFromTop = @"libactivator.two-finger-slide-in.top";
NSString *const LAEventNameTwoFingerSlideInFromTopLeft = @"libactivator.two-finger-slide-in.top-left";
NSString *const LAEventNameTwoFingerSlideInFromTopRight = @"libactivator.two-finger-slide-in.top-right";

NSString *const LAEventNameDragOffBottom = @"libactivator.drag-off.bottom";
NSString *const LAEventNameDragOffLeft = @"libactivator.drag-off.left";
NSString *const LAEventNameDragOffRight = @"libactivator.drag-off.right";
NSString *const LAEventNameDragOffTop = @"libactivator.drag-off.top";

NSString *const LAEventScreenBottomSwipeLeft = @"libactivator.screen.bottom.swipe.left";
NSString *const LAEventScreenBottomSwipeRight = @"libactivator.screen.bottom.swipe.right";
NSString *const LAEventScreenLeftSwipeDown = @"libactivator.screen.left.swipe.down";
NSString *const LAEventScreenLeftSwipeUp = @"libactivator.screen.left.swipe.up";
NSString *const LAEventScreenRightSwipeDown = @"libactivator.screen.right.swipe.down";
NSString *const LAEventScreenRightSwipeUp = @"libactivator.screen.right.swipe.up";

NSString *const LAEventNameMotionShake = @"libactivator.motion.shake";

NSString *const LAEventNameHeadsetButtonPressSingle = @"libactivator.headset-button.press.single";
NSString *const LAEventNameHeadsetButtonHoldShort = @"libactivator.headset-button.hold.short";
NSString *const LAEventNameHeadsetConnected = @"libactivator.headset.connected";
NSString *const LAEventNameHeadsetDisconnected = @"libactivator.headset.disconnected";

NSString *const LAEventNameLockScreenClockDoubleTap = @"libactivator.lockscreen.clock.double-tap";
NSString *const LAEventNameLockScreenClockTapHold = @"libactivator.lockscreen.clock.tap-hold";
NSString *const LAEventNameLockScreenClockSwipeLeft = @"libactivator.lockscreen.clock.swipe.left";
NSString *const LAEventNameLockScreenClockSwipeRight = @"libactivator.lockscreen.clock.swipe.right";
NSString *const LAEventNameLockScreenClockSwipeDown = @"libactivator.lockscreen.clock.swipe.down";

NSString *const LAEventNamePowerConnected = @"libactivator.power.connected";
NSString *const LAEventNamePowerDisconnected = @"libactivator.power.disconnected";

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

NSString *const LAEventNameSpringBoardIconFlickUp = @"libactivator.springboard.icon.flick.up";
NSString *const LAEventNameSpringBoardIconFlickDown = @"libactivator.springboard.icon.flick.down";
NSString *const LAEventNameSpringBoardIconFlickLeft = @"libactivator.springboard.icon.flick.left";
NSString *const LAEventNameSpringBoardIconFlickRight = @"libactivator.springboard.icon.flick.right";

NSString *const LAEventNameDeviceLocked = @"libactivator.device.locked";
NSString *const LAEventNameDeviceUnlocked = @"libactivator.device.unlocked";

NSString *const LAEventNameNetworkJoinedWiFi = @"libactivator.network.wifi.joined";
NSString *const LAEventNameNetworkLeftWiFi = @"libactivator.network.wifi.left";

NSString *const LAEventNameFingerprintSensorPressSingle = @"libactivator.fingerprint-sensor.press.single";

NSString *const LAEventUserInfoDisplayIdentifier = @"LAEventUserInfoDisplayIdentifier";
NSString *const LAEventUserInfoIconView = @"LAEventUserInfoIconView";
NSString *const LAEventUserInfoUnlockedDeviceToSendEvent = @"LAEventUserInfoUnlockedDeviceToSendEvent";
