//
//  LATestBuiltInEventSourcesSuite.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInEventSourcesSuite.h"

#import "LAActivator+Private.h"
#import "LATEdgeGestureClassifier.h"
#import "LATEdgeGestureEventSource.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATForceTouchEventSource.h"
#import "LATStatusBarEventSource.h"
#import "LATestEnvironment.h"

@implementation LATestBuiltInEventSourcesSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInEventSources"];

    NSString *nowPlayingInfoChangedEventName = @"libactivator.now-playing.info-changed";
    NSString *nowPlayingPlayingEventName = @"libactivator.now-playing.playing";
    NSString *nowPlayingPausedEventName = @"libactivator.now-playing.paused";
    NSString *lockPressTripleEventName = @"libactivator.lock.press.triple";
    NSArray<NSString *> *statusBarEventNames = @[
        LAEventNameStatusBarTapSingle,
        LAEventNameStatusBarTapSingleLeft,
        LAEventNameStatusBarTapSingleRight,
        LAEventNameStatusBarTapDouble,
        LAEventNameStatusBarTapDoubleLeft,
        LAEventNameStatusBarTapDoubleRight,
        LAEventNameStatusBarHold,
        LAEventNameStatusBarHoldLeft,
        LAEventNameStatusBarHoldRight,
        LAEventNameStatusBarSwipeLeft,
        LAEventNameStatusBarSwipeRight,
        LAEventNameStatusBarSwipeDown,
    ];

    [recorder expect:NSClassFromString(@"LATLockStateEventSource") != Nil
            caseName:@"lock-state-event-source-loaded"
              reason:@"LATLockStateEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATPowerStateEventSource") != Nil
            caseName:@"power-state-event-source-loaded"
              reason:@"LATPowerStateEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATMediaEventSource") != Nil
            caseName:@"media-event-source-loaded"
              reason:@"LATMediaEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATNetworkEventSource") != Nil
            caseName:@"network-event-source-loaded"
              reason:@"LATNetworkEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATButtonEventSource") != Nil
            caseName:@"button-event-source-loaded"
              reason:@"LATButtonEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATStatusBarEventSource") != Nil
            caseName:@"status-bar-event-source-loaded"
              reason:@"LATStatusBarEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATEdgeGestureClassifier") != Nil
            caseName:@"edge-gesture-classifier-loaded"
              reason:@"LATEdgeGestureClassifier class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATEdgeGestureEventSource") != Nil
            caseName:@"edge-gesture-event-source-loaded"
              reason:@"LATEdgeGestureEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATFingerprintSensorEventSource") != Nil
            caseName:@"fingerprint-sensor-event-source-loaded"
              reason:@"LATFingerprintSensorEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATForceTouchEventSource") != Nil
            caseName:@"force-touch-event-source-loaded"
              reason:@"LATForceTouchEventSource class was not loaded in SpringBoard"];
    [recorder expect:NSClassFromString(@"LATRuntimeStateSource") != Nil
            caseName:@"runtime-state-source-loaded"
              reason:@"LATRuntimeStateSource class was not loaded in SpringBoard"];
    for (NSString *eventName in statusBarEventNames) {
        [recorder expect:[[activator availableEventNames] containsObject:eventName]
                caseName:[NSString stringWithFormat:@"status-bar-event-available-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ metadata was not available", eventName]];
        [recorder expect:[activator eventWithName:eventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeApplication] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeLockScreen]
                caseName:[NSString stringWithFormat:@"status-bar-event-all-modes-compatible-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ was not compatible with all event modes", eventName]];
    }
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameDeviceLocked]
            caseName:@"device-locked-event-available"
              reason:@"Device locked event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameDeviceUnlocked]
            caseName:@"device-unlocked-event-available"
              reason:@"Device unlocked event metadata was not available"];
    [recorder expect:[activator eventWithName:LAEventNameDeviceLocked isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"device-locked-lockscreen-compatible"
              reason:@"Device locked event was not compatible with lock screen mode"];
    [recorder expect:![activator eventWithName:LAEventNameDeviceLocked isCompatibleWithMode:LAEventModeSpringBoard]
            caseName:@"device-locked-springboard-incompatible"
              reason:@"Device locked event was compatible with SpringBoard mode"];
    [recorder expect:[activator eventWithName:LAEventNameDeviceUnlocked isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameDeviceUnlocked isCompatibleWithMode:LAEventModeApplication]
            caseName:@"device-unlocked-underneath-compatible"
              reason:@"Device unlocked event was not compatible with unlocked modes"];
    [recorder expect:![activator eventWithName:LAEventNameDeviceUnlocked isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"device-unlocked-lockscreen-incompatible"
              reason:@"Device unlocked event was compatible with lock screen mode"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNamePowerConnected]
            caseName:@"power-connected-event-available"
              reason:@"Power connected event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNamePowerDisconnected]
            caseName:@"power-disconnected-event-available"
              reason:@"Power disconnected event metadata was not available"];
    [recorder expect:[activator eventWithName:LAEventNamePowerConnected isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNamePowerConnected isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNamePowerConnected isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"power-connected-all-modes-compatible"
              reason:@"Power connected event was not compatible with all event modes"];
    [recorder
          expect:[activator eventWithName:LAEventNamePowerDisconnected isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNamePowerDisconnected isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNamePowerDisconnected isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"power-disconnected-all-modes-compatible"
          reason:@"Power disconnected event was not compatible with all event modes"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameHeadsetConnected]
            caseName:@"headset-connected-event-available"
              reason:@"Headset connected event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameHeadsetDisconnected]
            caseName:@"headset-disconnected-event-available"
              reason:@"Headset disconnected event metadata was not available"];
    [recorder
          expect:[activator eventWithName:LAEventNameHeadsetConnected isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameHeadsetConnected isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameHeadsetConnected isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"headset-connected-all-modes-compatible"
          reason:@"Headset connected event was not compatible with all event modes"];
    [recorder
          expect:[activator eventWithName:LAEventNameHeadsetDisconnected isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameHeadsetDisconnected isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameHeadsetDisconnected isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"headset-disconnected-all-modes-compatible"
          reason:@"Headset disconnected event was not compatible with all event modes"];
    [recorder expect:[[activator availableEventNames] containsObject:nowPlayingInfoChangedEventName]
            caseName:@"now-playing-info-changed-event-available"
              reason:@"Now playing info changed event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:nowPlayingPlayingEventName]
            caseName:@"now-playing-playing-event-available"
              reason:@"Now playing playing event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:nowPlayingPausedEventName]
            caseName:@"now-playing-paused-event-available"
              reason:@"Now playing paused event metadata was not available"];
    [recorder
          expect:[activator eventWithName:nowPlayingInfoChangedEventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:nowPlayingInfoChangedEventName isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:nowPlayingInfoChangedEventName isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"now-playing-info-changed-all-modes-compatible"
          reason:@"Now playing info changed event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:nowPlayingPlayingEventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:nowPlayingPlayingEventName isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:nowPlayingPlayingEventName isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"now-playing-playing-all-modes-compatible"
              reason:@"Now playing playing event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:nowPlayingPausedEventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:nowPlayingPausedEventName isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:nowPlayingPausedEventName isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"now-playing-paused-all-modes-compatible"
              reason:@"Now playing paused event was not compatible with all event modes"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameNetworkJoinedWiFi]
            caseName:@"wifi-joined-event-available"
              reason:@"Wi-Fi joined event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameNetworkLeftWiFi]
            caseName:@"wifi-left-event-available"
              reason:@"Wi-Fi left event metadata was not available"];
    [recorder
          expect:[activator eventWithName:LAEventNameNetworkJoinedWiFi isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameNetworkJoinedWiFi isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameNetworkJoinedWiFi isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"wifi-joined-all-modes-compatible"
          reason:@"Wi-Fi joined event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameNetworkLeftWiFi isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameNetworkLeftWiFi isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameNetworkLeftWiFi isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"wifi-left-all-modes-compatible"
              reason:@"Wi-Fi left event was not compatible with all event modes"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeUpPress]
            caseName:@"volume-up-press-event-available"
              reason:@"Volume up press event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeDownPress]
            caseName:@"volume-down-press-event-available"
              reason:@"Volume down press event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeBothPress]
            caseName:@"volume-both-press-event-available"
              reason:@"Volume both press event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeUpDown]
            caseName:@"volume-up-down-event-available"
              reason:@"Volume up-down event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeDownUp]
            caseName:@"volume-down-up-event-available"
              reason:@"Volume down-up event metadata was not available"];
    NSArray<NSString *> *availableEventNames = [activator availableEventNames];
    BOOL volumeUpPressWithMenuIsAvailable = [availableEventNames containsObject:LAEventNameVolumeUpPressWithMenu];
    BOOL volumeDownPressWithMenuIsAvailable = [availableEventNames containsObject:LAEventNameVolumeDownPressWithMenu];
    BOOL lockPressWithMenuIsAvailable = [availableEventNames containsObject:LAEventNameLockPressWithMenu];
    BOOL menuHoldLongIsAvailable = [availableEventNames containsObject:LAEventNameMenuHoldLong];
    BOOL menuHoldShortIsAvailable = [availableEventNames containsObject:LAEventNameMenuHoldShort];
    BOOL menuPressDoubleIsAvailable = [availableEventNames containsObject:LAEventNameMenuPressDouble];
    BOOL menuPressSingleIsAvailable = [availableEventNames containsObject:LAEventNameMenuPressSingle];
    BOOL menuPressTripleIsAvailable = [availableEventNames containsObject:LAEventNameMenuPressTriple];
    [recorder expect:volumeUpPressWithMenuIsAvailable == volumeDownPressWithMenuIsAvailable
            caseName:@"volume-with-menu-events-share-capability-filter"
              reason:@"Volume with menu events did not share the same required-capabilities filter"];
    [recorder expect:lockPressWithMenuIsAvailable == menuPressSingleIsAvailable
            caseName:@"lock-press-with-menu-shares-menu-capability-filter"
              reason:@"Lock press with menu event did not share the real home button capability filter"];
    [recorder expect:menuHoldLongIsAvailable == menuHoldShortIsAvailable &&
                     menuHoldShortIsAvailable == menuPressDoubleIsAvailable &&
                     menuPressDoubleIsAvailable == menuPressSingleIsAvailable &&
                     menuPressSingleIsAvailable == menuPressTripleIsAvailable
            caseName:@"menu-button-events-share-capability-filter"
              reason:@"Menu button events did not share the same required-capabilities filter"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeUpHoldShort]
            caseName:@"volume-up-hold-short-event-available"
              reason:@"Volume up short hold event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeDownHoldShort]
            caseName:@"volume-down-hold-short-event-available"
              reason:@"Volume down short hold event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeMuteOn]
            caseName:@"volume-mute-event-available"
              reason:@"Volume mute event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeMuteOff]
            caseName:@"volume-unmute-event-available"
              reason:@"Volume unmute event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeToggleMuteTwice]
            caseName:@"volume-toggle-mute-twice-event-available"
              reason:@"Volume toggle mute twice event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameLockHoldLong]
            caseName:@"lock-hold-long-event-available"
              reason:@"Lock long hold event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameLockHoldShort]
            caseName:@"lock-hold-short-event-available"
              reason:@"Lock short hold event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameLockPressDouble]
            caseName:@"lock-press-double-event-available"
              reason:@"Lock double press event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:lockPressTripleEventName]
            caseName:@"lock-press-triple-event-available"
              reason:@"Lock triple press event metadata was not available"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeUpPress isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeUpPress isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeUpPress isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-up-press-all-modes-compatible"
              reason:@"Volume up press event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeDownPress isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeDownPress isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeDownPress isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-down-press-all-modes-compatible"
              reason:@"Volume down press event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeBothPress isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeBothPress isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeBothPress isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-both-press-all-modes-compatible"
              reason:@"Volume both press event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeUpDown isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeUpDown isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeUpDown isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-up-down-all-modes-compatible"
              reason:@"Volume up-down event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeDownUp isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeDownUp isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeDownUp isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-down-up-all-modes-compatible"
              reason:@"Volume down-up event was not compatible with all event modes"];
    [recorder expect:!volumeUpPressWithMenuIsAvailable || ([activator eventWithName:LAEventNameVolumeUpPressWithMenu
                                                               isCompatibleWithMode:LAEventModeSpringBoard] &&
                                                           [activator eventWithName:LAEventNameVolumeUpPressWithMenu
                                                               isCompatibleWithMode:LAEventModeApplication] &&
                                                           [activator eventWithName:LAEventNameVolumeUpPressWithMenu
                                                               isCompatibleWithMode:LAEventModeLockScreen])
            caseName:@"volume-up-press-with-menu-all-modes-compatible-when-available"
              reason:@"Available volume up press with menu event was not compatible with all event modes"];
    [recorder expect:!volumeDownPressWithMenuIsAvailable || ([activator eventWithName:LAEventNameVolumeDownPressWithMenu
                                                                 isCompatibleWithMode:LAEventModeSpringBoard] &&
                                                             [activator eventWithName:LAEventNameVolumeDownPressWithMenu
                                                                 isCompatibleWithMode:LAEventModeApplication] &&
                                                             [activator eventWithName:LAEventNameVolumeDownPressWithMenu
                                                                 isCompatibleWithMode:LAEventModeLockScreen])
            caseName:@"volume-down-press-with-menu-all-modes-compatible-when-available"
              reason:@"Available volume down press with menu event was not compatible with all event modes"];
    [recorder expect:!menuHoldLongIsAvailable ||
                     ([activator eventWithName:LAEventNameMenuHoldLong isCompatibleWithMode:LAEventModeSpringBoard] &&
                      [activator eventWithName:LAEventNameMenuHoldLong isCompatibleWithMode:LAEventModeApplication] &&
                      [activator eventWithName:LAEventNameMenuHoldLong isCompatibleWithMode:LAEventModeLockScreen])
            caseName:@"menu-hold-long-all-modes-compatible-when-available"
              reason:@"Available menu long hold event was not compatible with all event modes"];
    [recorder expect:!menuHoldShortIsAvailable ||
                     ([activator eventWithName:LAEventNameMenuHoldShort isCompatibleWithMode:LAEventModeSpringBoard] &&
                      [activator eventWithName:LAEventNameMenuHoldShort isCompatibleWithMode:LAEventModeApplication] &&
                      [activator eventWithName:LAEventNameMenuHoldShort isCompatibleWithMode:LAEventModeLockScreen])
            caseName:@"menu-hold-short-all-modes-compatible-when-available"
              reason:@"Available menu short hold event was not compatible with all event modes"];
    [recorder
          expect:!menuPressDoubleIsAvailable ||
                 ([activator eventWithName:LAEventNameMenuPressDouble isCompatibleWithMode:LAEventModeSpringBoard] &&
                  [activator eventWithName:LAEventNameMenuPressDouble isCompatibleWithMode:LAEventModeApplication] &&
                  [activator eventWithName:LAEventNameMenuPressDouble isCompatibleWithMode:LAEventModeLockScreen])
        caseName:@"menu-press-double-all-modes-compatible-when-available"
          reason:@"Available menu double press event was not compatible with all event modes"];
    [recorder
          expect:!menuPressSingleIsAvailable ||
                 ([activator eventWithName:LAEventNameMenuPressSingle isCompatibleWithMode:LAEventModeSpringBoard] &&
                  [activator eventWithName:LAEventNameMenuPressSingle isCompatibleWithMode:LAEventModeApplication] &&
                  [activator eventWithName:LAEventNameMenuPressSingle isCompatibleWithMode:LAEventModeLockScreen])
        caseName:@"menu-press-single-all-modes-compatible-when-available"
          reason:@"Available menu single press event was not compatible with all event modes"];
    [recorder
          expect:!menuPressTripleIsAvailable ||
                 ([activator eventWithName:LAEventNameMenuPressTriple isCompatibleWithMode:LAEventModeSpringBoard] &&
                  [activator eventWithName:LAEventNameMenuPressTriple isCompatibleWithMode:LAEventModeApplication] &&
                  [activator eventWithName:LAEventNameMenuPressTriple isCompatibleWithMode:LAEventModeLockScreen])
        caseName:@"menu-press-triple-all-modes-compatible-when-available"
          reason:@"Available menu triple press event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameLockHoldLong isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameLockHoldLong isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameLockHoldLong isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"lock-hold-long-all-modes-compatible"
              reason:@"Lock long hold event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameLockHoldShort isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameLockHoldShort isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameLockHoldShort isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"lock-hold-short-all-modes-compatible"
              reason:@"Lock short hold event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameLockPressDouble isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameLockPressDouble isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameLockPressDouble isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"lock-press-double-all-modes-compatible"
              reason:@"Lock double press event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:lockPressTripleEventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:lockPressTripleEventName isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:lockPressTripleEventName isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"lock-press-triple-all-modes-compatible"
              reason:@"Lock triple press event was not compatible with all event modes"];
    [recorder
          expect:!lockPressWithMenuIsAvailable ||
                 ([activator eventWithName:LAEventNameLockPressWithMenu isCompatibleWithMode:LAEventModeSpringBoard] &&
                  [activator eventWithName:LAEventNameLockPressWithMenu isCompatibleWithMode:LAEventModeApplication] &&
                  [activator eventWithName:LAEventNameLockPressWithMenu isCompatibleWithMode:LAEventModeLockScreen])
        caseName:@"lock-press-with-menu-all-modes-compatible-when-available"
          reason:@"Available lock press with menu event was not compatible with all event modes"];
    [recorder
          expect:[activator eventWithName:LAEventNameVolumeUpHoldShort isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameVolumeUpHoldShort isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameVolumeUpHoldShort isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"volume-up-hold-short-all-modes-compatible"
          reason:@"Volume up short hold event was not compatible with all event modes"];
    [recorder
          expect:[activator eventWithName:LAEventNameVolumeDownHoldShort isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameVolumeDownHoldShort isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameVolumeDownHoldShort isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"volume-down-hold-short-all-modes-compatible"
          reason:@"Volume down short hold event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeMuteOn isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeMuteOn isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeMuteOn isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-mute-all-modes-compatible"
              reason:@"Volume mute event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeMuteOff isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeMuteOff isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeMuteOff isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-unmute-all-modes-compatible"
              reason:@"Volume unmute event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeToggleMuteTwice
                         isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeToggleMuteTwice
                         isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeToggleMuteTwice
                         isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-toggle-mute-twice-all-modes-compatible"
              reason:@"Volume toggle mute twice event was not compatible with all event modes"];

    [self runFingerprintSensorAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runForceTouchAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runStatusBarRecognizerTestsWithRecorder:recorder activator:activator];
    [self runEdgeGestureClassifierTestsWithRecorder:recorder];
    [self runFingerprintSensorRecognizerTestsWithRecorder:recorder activator:activator];
    [self runEdgeGestureEventSourceDispatchTestsWithRecorder:recorder activator:activator];
    [self runForceTouchEventSourceTestsWithRecorder:recorder activator:activator];
}

+ (NSUInteger)dispatchCountForEventName:(NSString *)eventName activator:(LAActivator *)activator {
    return [activator.la_eventDispatchCounts[eventName] unsignedIntegerValue];
}

+ (void)runFingerprintSensorAvailabilityTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    NSArray<NSString *> *eventNames = @[
        LAEventNameFingerprintSensorPressSingle,
        LAEventNameFingerprintSensorPressTwice,
        LAEventNameFingerprintSensorHold,
        LAEventNameFingerprintSensorHoldLong,
        LAEventNameFingerprintSensorPressSingleAndSlideIn,
        LAEventNameFingerprintSensorPressSingleAndHold,
    ];

    NSArray<NSString *> *availableEventNames = [activator availableEventNames];
    BOOL anyEventAvailable = NO;
    BOOL allEventsAvailable = YES;
    for (NSString *eventName in eventNames) {
        BOOL eventAvailable = [availableEventNames containsObject:eventName];
        anyEventAvailable = anyEventAvailable || eventAvailable;
        allEventsAvailable = allEventsAvailable && eventAvailable;
    }

    [recorder expect:anyEventAvailable == allEventsAvailable
            caseName:@"fingerprint-sensor-events-share-capability-filter"
              reason:@"Fingerprint sensor events did not share the touch-id capability filter"];

    if (!anyEventAvailable) {
        return;
    }

    for (NSString *eventName in eventNames) {
        [recorder expect:[activator eventWithName:eventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeApplication] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeLockScreen]
                caseName:[NSString stringWithFormat:@"fingerprint-sensor-event-all-modes-compatible-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ was not compatible with all event modes", eventName]];
    }
}

+ (void)runForceTouchAvailabilityTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    NSArray<NSString *> *eventNames = [self forceTouchEventNames];
    NSArray<NSString *> *availableEventNames = [activator availableEventNames];
    BOOL anyEventAvailable = NO;
    BOOL allEventsAvailable = YES;
    for (NSString *eventName in eventNames) {
        BOOL eventAvailable = [availableEventNames containsObject:eventName];
        anyEventAvailable = anyEventAvailable || eventAvailable;
        allEventsAvailable = allEventsAvailable && eventAvailable;
    }

    [recorder expect:anyEventAvailable == allEventsAvailable
            caseName:@"force-touch-events-share-capability-filter"
              reason:@"Force touch events did not share the SupportsForceTouch capability filter"];

    if (!anyEventAvailable) {
        return;
    }

    for (NSString *eventName in eventNames) {
        [recorder expect:[activator eventWithName:eventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeApplication] &&
                         [activator eventWithName:eventName isCompatibleWithMode:LAEventModeLockScreen]
                caseName:[NSString stringWithFormat:@"force-touch-event-all-modes-compatible-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ was not compatible with all event modes", eventName]];
    }
}

+ (void)runStatusBarRecognizerTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    Class sourceClass = NSClassFromString(@"LATStatusBarEventSource");
    if (!sourceClass) {
        [recorder skip:@"status-bar-recognizer-logic" reason:@"LATStatusBarEventSource was not loaded"];
        return;
    }

    LATStatusBarEventSource *source = [[sourceClass alloc] init];
    [source start];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 40.0);

    [activator la_resetDispatchCounts];
    NSObject *leftView = [[NSObject alloc] init];
    [source la_testingNoteTouchBeganInStatusBarView:leftView bounds:bounds location:CGPointMake(40.0, 10.0) tapCount:1];
    [source la_testingNoteTouchEndedInStatusBarView:leftView tapCount:1];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.4];
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarTapSingleLeft activator:activator] == 1
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarTapDouble activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 1
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarTapDoubleRight activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingleRight activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarHoldRight activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingleRight activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarHold activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarSwipeRight activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarSwipeRight activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarSwipeDown activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarHold activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarHold activator:activator] == 0 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingle activator:activator] == 0
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
    [recorder expect:[self dispatchCountForEventName:LAEventNameStatusBarTapSingleLeft activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameStatusBarTapSingleRight activator:activator] == 0
            caseName:@"status-bar-sessions-are-per-view"
              reason:@"A second status bar view cancelled or polluted the first view session"];
}

+ (void)runForceTouchEventSourceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    Class sourceClass = NSClassFromString(@"LATForceTouchEventSource");
    if (!sourceClass) {
        [recorder skip:@"force-touch-event-source-logic" reason:@"LATForceTouchEventSource was not loaded"];
        return;
    }

    LATForceTouchEventSource *source = [[sourceClass alloc] init];
    [source start];
    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);
    NSArray<NSDictionary<NSString *, id> *> *regionCases = @[
        @{
            @"Case" : @"force-touch-classifies-statusbar",
            @"EventName" : @"libactivator.force-touch.statusbar",
            @"Location" : [self forceTouchPointWithX:200.0 y:37.0],
        },
        @{
            @"Case" : @"force-touch-classifies-left-edge",
            @"EventName" : @"libactivator.force-touch.screen-left",
            @"Location" : [self forceTouchPointWithX:13.0 y:400.0],
        },
        @{
            @"Case" : @"force-touch-classifies-right-edge",
            @"EventName" : @"libactivator.force-touch.screen-right",
            @"Location" : [self forceTouchPointWithX:387.0 y:400.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom-left",
            @"EventName" : @"libactivator.force-touch.screen-bottom-left",
            @"Location" : [self forceTouchPointWithX:90.0 y:762.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom",
            @"EventName" : @"libactivator.force-touch.screen-bottom",
            @"Location" : [self forceTouchPointWithX:200.0 y:762.0],
        },
        @{
            @"Case" : @"force-touch-classifies-bottom-right",
            @"EventName" : @"libactivator.force-touch.screen-bottom-right",
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

    LATForceTouchEventSource *notStartedSource = [[sourceClass alloc] init];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                           bounds:bounds
                                        timestamp:0.0];
    NSString *notStartedEventName =
        [notStartedSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:1
                                         location:CGPointMake(200.0, 762.0)
                                            force:5.0],
        ]
                                               bounds:bounds
                                            timestamp:0.1];
    [recorder expect:notStartedEventName == nil &&
                     [self dispatchCountForEventName:@"libactivator.force-touch.screen-bottom" activator:activator] == 0
            caseName:@"force-touch-ignores-events-before-start"
              reason:@"Force touch event source dispatched before it was started"];

    LATForceTouchEventSource *dispatchSource = [[sourceClass alloc] init];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    [dispatchSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                         bounds:bounds
                                      timestamp:0.0];
    NSString *belowThresholdEventName =
        [dispatchSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:1
                                         location:CGPointMake(200.0, 762.0)
                                            force:4.99],
        ]
                                             bounds:bounds
                                          timestamp:0.1];
    NSString *firstEventName =
        [dispatchSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:1
                                         location:CGPointMake(200.0, 762.0)
                                            force:5.0],
        ]
                                             bounds:bounds
                                          timestamp:0.2];
    NSString *secondEventName =
        [dispatchSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:1
                                         location:CGPointMake(200.0, 762.0)
                                            force:6.0],
        ]
                                             bounds:bounds
                                          timestamp:0.3];
    [recorder expect:belowThresholdEventName == nil &&
                     [firstEventName isEqualToString:@"libactivator.force-touch.screen-bottom"] &&
                     secondEventName == nil &&
                     [self dispatchCountForEventName:@"libactivator.force-touch.screen-bottom" activator:activator] == 1
            caseName:@"force-touch-dispatches-on-threshold-once"
              reason:@"Force touch did not dispatch exactly once when force crossed the threshold"];

    LATForceTouchEventSource *endedSource = [[sourceClass alloc] init];
    [endedSource start];
    [activator la_resetDispatchCounts];
    [endedSource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                      bounds:bounds
                                   timestamp:0.0];
    NSString *endedEventName =
        [endedSource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:3
                                         location:CGPointMake(200.0, 762.0)
                                            force:6.0],
        ]
                                          bounds:bounds
                                       timestamp:0.1];
    [recorder expect:endedEventName == nil &&
                     [self dispatchCountForEventName:@"libactivator.force-touch.screen-bottom" activator:activator] == 0
            caseName:@"force-touch-ignores-ended-threshold-crossing"
              reason:@"Force touch dispatched after the touch had already ended"];

    LATForceTouchEventSource *movedAwaySource = [[sourceClass alloc] init];
    [movedAwaySource start];
    [activator la_resetDispatchCounts];
    [movedAwaySource la_testingNoteTouchSnapshots:@[
        [self forceTouchSnapshotWithIdentifier:@"touch-0" phase:0 location:CGPointMake(200.0, 762.0) force:0.0],
    ]
                                        bounds:bounds
                                     timestamp:0.0];
    NSString *movedAwayEventName =
        [movedAwaySource la_testingNoteTouchSnapshots:@[
            [self forceTouchSnapshotWithIdentifier:@"touch-0"
                                            phase:1
                                         location:CGPointMake(200.0, 500.0)
                                            force:6.0],
        ]
                                             bounds:bounds
                                          timestamp:0.1];
    [recorder expect:movedAwayEventName == nil &&
                     [self dispatchCountForEventName:@"libactivator.force-touch.screen-bottom" activator:activator] == 0
            caseName:@"force-touch-requires-same-region-at-threshold"
              reason:@"Force touch dispatched after the touch moved outside its starting region"];
}

+ (void)runFingerprintSensorRecognizerTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    Class sourceClass = NSClassFromString(@"LATFingerprintSensorEventSource");
    if (!sourceClass) {
        [recorder skip:@"fingerprint-sensor-recognizer-logic"
                reason:@"LATFingerprintSensorEventSource was not loaded"];
        return;
    }

    if (![[activator availableEventNames] containsObject:LAEventNameFingerprintSensorPressSingle]) {
        [recorder skip:@"fingerprint-sensor-recognizer-logic"
                reason:@"Fingerprint sensor metadata is not available on this device"];
        return;
    }

    LATFingerprintSensorEventSource *notStartedSource = [[sourceClass alloc] init];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [notStartedSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [notStartedSource la_testingResolvePendingSinglePress];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"fingerprint-sensor-ignores-events-before-start"
              reason:@"Fingerprint sensor event source dispatched before it was started"];

    LATFingerprintSensorEventSource *postUnlockSource = [[sourceClass alloc] init];
    [postUnlockSource start];
    [activator la_resetDispatchCounts];
    [postUnlockSource noteDeviceUnlockedAtTimestamp:1.0];
    [postUnlockSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:1.1];
    [postUnlockSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:1.2];
    [postUnlockSource la_testingResolvePendingSinglePress];
    [postUnlockSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:1.3];
    [postUnlockSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:1.4];
    [postUnlockSource la_testingResolvePendingSinglePress];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 1
            caseName:@"fingerprint-sensor-ignores-events-after-unlock"
              reason:@"Fingerprint sensor event source did not ignore only the post-unlock suppression window"];

    LATFingerprintSensorEventSource *singlePressSource = [[sourceClass alloc] init];
    [singlePressSource start];
    [activator la_resetDispatchCounts];
    [singlePressSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [singlePressSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [singlePressSource la_testingResolvePendingSinglePress];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 1
            caseName:@"fingerprint-sensor-dispatches-single-press"
              reason:@"Fingerprint sensor single press did not dispatch"];

    LATFingerprintSensorEventSource *doublePressSource = [[sourceClass alloc] init];
    [doublePressSource start];
    [activator la_resetDispatchCounts];
    [doublePressSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [doublePressSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [doublePressSource la_testingNoteTouchIDDown:YES sequenceState:1 timestamp:0.2];
    [doublePressSource la_testingNoteTouchIDDown:NO sequenceState:2 timestamp:0.3];
    [doublePressSource la_testingResolvePendingSinglePress];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorPressTwice activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"fingerprint-sensor-dispatches-double-press"
              reason:@"Fingerprint sensor double press did not dispatch or leaked a single press"];

    LATFingerprintSensorEventSource *holdSource = [[sourceClass alloc] init];
    [holdSource start];
    [activator la_resetDispatchCounts];
    [holdSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [holdSource la_testingSendShortHoldIfNeeded];
    [holdSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.8];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorHold activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"fingerprint-sensor-dispatches-short-hold"
              reason:@"Fingerprint sensor short hold did not dispatch or leaked a single press"];

    LATFingerprintSensorEventSource *longHoldSource = [[sourceClass alloc] init];
    [longHoldSource start];
    [activator la_resetDispatchCounts];
    [longHoldSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [longHoldSource la_testingSendShortHoldIfNeeded];
    [longHoldSource la_testingSendLongHoldIfNeeded];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorHold activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorHoldLong activator:activator] == 1
            caseName:@"fingerprint-sensor-dispatches-long-hold"
              reason:@"Fingerprint sensor long hold did not dispatch after short hold"];

    LATFingerprintSensorEventSource *pressHoldSource = [[sourceClass alloc] init];
    [pressHoldSource start];
    [activator la_resetDispatchCounts];
    [pressHoldSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [pressHoldSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    [pressHoldSource la_testingNoteTouchIDDown:YES sequenceState:1 timestamp:0.2];
    [pressHoldSource la_testingSendShortHoldIfNeeded];
    [recorder expect:[self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndHold
                                           activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressTwice activator:activator] == 0 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"fingerprint-sensor-dispatches-single-press-with-hold"
              reason:@"Fingerprint sensor single press with hold did not dispatch or leaked another press event"];

    LATFingerprintSensorEventSource *slideInSource = [[sourceClass alloc] init];
    [slideInSource start];
    [activator la_resetDispatchCounts];
    [slideInSource la_testingNoteTouchIDDown:YES sequenceState:0 timestamp:0.0];
    [slideInSource la_testingNoteTouchIDDown:NO sequenceState:1 timestamp:0.1];
    BOOL consumed = [slideInSource consumePendingSinglePressForSlideInAtTimestamp:0.4];
    [slideInSource la_testingResolvePendingSinglePress];
    [recorder expect:consumed &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndSlideIn
                                           activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"fingerprint-sensor-dispatches-single-press-with-slide-in"
              reason:@"Fingerprint sensor single press with slide-in did not dispatch or leaked a single press"];
}

+ (void)runEdgeGestureClassifierTestsWithRecorder:(LATestRecorder *)recorder {
    Class classifierClass = NSClassFromString(@"LATEdgeGestureClassifier");
    if (!classifierClass) {
        [recorder skip:@"edge-gesture-classifier-logic" reason:@"LATEdgeGestureClassifier was not loaded"];
        return;
    }

    LATEdgeGestureClassifier *classifier = [[classifierClass alloc] init];
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
            @"EventName" : @"libactivator.slide-in.left-top",
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
            @"EventName" : @"libactivator.slide-in.left-bottom",
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:720.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:720.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-right-top",
            @"EventName" : @"libactivator.slide-in.right-top",
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
            @"EventName" : @"libactivator.slide-in.right-bottom",
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
            @"EventName" : @"libactivator.two-finger-slide-in.left-top",
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
            @"EventName" : @"libactivator.two-finger-slide-in.left-bottom",
            @"Start" : @[ [self edgeGesturePointWithX:2.0 y:716.0], [self edgeGesturePointWithX:2.0 y:724.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:80.0 y:716.0], [self edgeGesturePointWithX:80.0 y:724.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-two-finger-right-top",
            @"EventName" : @"libactivator.two-finger-slide-in.right-top",
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
            @"EventName" : @"libactivator.two-finger-slide-in.right-bottom",
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
                                                                  startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
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
    [recorder expect:dragOffMovedEventName == nil &&
                     dragOffCancelledEventName == nil &&
                     dragOffCornerEventName == nil
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
    NSString *wideTwoFingerLeftEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:26.0 y:323.0],
                                                              [self edgeGesturePointWithX:26.0 y:413.7] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:74.0 y:323.0],
                                                              [self edgeGesturePointWithX:74.0 y:413.7] ]];
    NSString *wideTwoFingerRightEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:388.0 y:323.0],
                                                              [self edgeGesturePointWithX:387.0 y:413.7] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:340.0 y:323.0],
                                                              [self edgeGesturePointWithX:340.0 y:413.7] ]];
    [recorder expect:wideSingleFingerLeftEventName == nil && wideSingleFingerRightEventName == nil
                     && wideTwoFingerLeftEventName == nil && wideTwoFingerRightEventName == nil
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
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:798.0] ]
                                                                           phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    NSString *firstEventName =
        [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:700.0] ]
                                                                               phase:1]
                                      bounds:bounds
                                   timestamp:0.1];
    NSString *secondEventName =
        [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:650.0] ]
                                                                               phase:1]
                                      bounds:bounds
                                   timestamp:0.2];
    [recorder expect:[firstEventName isEqualToString:LAEventNameSlideInFromBottom] && secondEventName == nil
            caseName:@"edge-gesture-classifies-once-per-session"
              reason:@"A single edge gesture session did not classify exactly once"];

    [classifier reset];
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:120.0 y:788.0] ]
                                                                           phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    NSString *firstDragEventName =
        [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:160.0 y:788.0] ]
                                                                               phase:1]
                                      bounds:bounds
                                   timestamp:0.1];
    NSString *secondDragEventName =
        [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[ [self edgeGesturePointWithX:200.0 y:788.0] ]
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

+ (void)runEdgeGestureEventSourceDispatchTestsWithRecorder:(LATestRecorder *)recorder
                                                 activator:(LAActivator *)activator {
    Class sourceClass = NSClassFromString(@"LATEdgeGestureEventSource");
    if (!sourceClass) {
        [recorder skip:@"edge-gesture-event-source-dispatch" reason:@"LATEdgeGestureEventSource was not loaded"];
        return;
    }

    CGRect bounds = CGRectMake(0.0, 0.0, 400.0, 800.0);

    LATEdgeGestureEventSource *notStartedSource = [[sourceClass alloc] init];
    [activator la_resetDispatchCounts];
    [notStartedSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                             [self edgeGesturePointWithX:200.0 y:798.0],
                                         ]
                                                                                     phase:0]
                                           bounds:bounds
                                        timestamp:0.0];
    NSString *notStartedEventName =
        [notStartedSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                                 [self edgeGesturePointWithX:200.0 y:700.0]
                                             ]
                                                                                         phase:1]
                                               bounds:bounds
                                            timestamp:0.1];
    [recorder expect:notStartedEventName == nil &&
                     [self dispatchCountForEventName:LAEventNameSlideInFromBottom activator:activator] == 0
            caseName:@"edge-gesture-event-source-ignores-events-before-start"
              reason:@"Edge gesture event source dispatched before it was started"];

    LATEdgeGestureEventSource *dispatchSource = [[sourceClass alloc] init];
    [dispatchSource start];
    [activator la_resetDispatchCounts];
    [dispatchSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                          [self edgeGesturePointWithX:200.0 y:798.0],
                                      ]
                                                                                  phase:0]
                                        bounds:bounds
                                     timestamp:0.0];
    NSString *firstEventName =
        [dispatchSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                               [self edgeGesturePointWithX:200.0 y:700.0]
                                           ]
                                                                                       phase:1]
                                             bounds:bounds
                                          timestamp:0.1];
    NSString *secondEventName =
        [dispatchSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                               [self edgeGesturePointWithX:200.0 y:650.0]
                                           ]
                                                                                       phase:1]
                                             bounds:bounds
                                          timestamp:0.2];
    [recorder expect:[firstEventName isEqualToString:LAEventNameSlideInFromBottom] && secondEventName == nil &&
                     [self dispatchCountForEventName:LAEventNameSlideInFromBottom activator:activator] == 1
            caseName:@"edge-gesture-event-source-dispatches-once"
              reason:@"Edge gesture event source did not dispatch exactly once for a classified gesture"];

    LATEdgeGestureEventSource *shortMoveSource = [[sourceClass alloc] init];
    [shortMoveSource start];
    [activator la_resetDispatchCounts];
    [shortMoveSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                           [self edgeGesturePointWithX:200.0 y:798.0],
                                       ]
                                                                                   phase:0]
                                         bounds:bounds
                                      timestamp:0.0];
    NSString *shortMoveEventName =
        [shortMoveSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                                [self edgeGesturePointWithX:200.0 y:750.0]
                                            ]
                                                                                        phase:1]
                                              bounds:bounds
                                           timestamp:0.1];
    [recorder expect:shortMoveEventName == nil &&
                     [self dispatchCountForEventName:LAEventNameSlideInFromBottom activator:activator] == 0
            caseName:@"edge-gesture-event-source-ignores-unclassified-move"
              reason:@"Edge gesture event source dispatched for an unclassified gesture"];

    LATEdgeGestureEventSource *dragAlongSource = [[sourceClass alloc] init];
    [dragAlongSource start];
    [activator la_resetDispatchCounts];
    [dragAlongSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                           [self edgeGesturePointWithX:120.0 y:788.0],
                                       ]
                                                                                   phase:0]
                                         bounds:bounds
                                      timestamp:0.0];
    NSString *dragAlongEventName =
        [dragAlongSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                                [self edgeGesturePointWithX:160.0 y:788.0]
                                            ]
                                                                                        phase:1]
                                              bounds:bounds
                                           timestamp:0.1];
    [recorder expect:[dragAlongEventName isEqualToString:LAEventScreenBottomSwipeRight] &&
                     [self dispatchCountForEventName:LAEventScreenBottomSwipeRight activator:activator] == 1
            caseName:@"edge-gesture-event-source-dispatches-drag-along"
              reason:@"Edge gesture event source did not dispatch a classified drag-along gesture"];

    LATEdgeGestureEventSource *dragOffSource = [[sourceClass alloc] init];
    [dragOffSource start];
    [activator la_resetDispatchCounts];
    [dragOffSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                        [self edgeGesturePointWithX:200.0 y:400.0],
                                    ]
                                                                                phase:0]
                                      bounds:bounds
                                   timestamp:0.0];
    NSString *dragOffMoveEventName =
        [dragOffSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                             [self edgeGesturePointWithX:10.0 y:400.0]
                                         ]
                                                                                     phase:1]
                                           bounds:bounds
                                        timestamp:0.1];
    NSString *dragOffEventName =
        [dragOffSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                             [self edgeGesturePointWithX:10.0 y:400.0]
                                         ]
                                                                                     phase:3]
                                           bounds:bounds
                                        timestamp:0.2];
    [recorder expect:dragOffMoveEventName == nil &&
                     [dragOffEventName isEqualToString:LAEventNameDragOffLeft] &&
                     [self dispatchCountForEventName:LAEventNameDragOffLeft activator:activator] == 1
            caseName:@"edge-gesture-event-source-dispatches-drag-off"
              reason:@"Edge gesture event source did not dispatch drag-off exactly once on touch end"];

    Class fingerprintSourceClass = NSClassFromString(@"LATFingerprintSensorEventSource");
    if (!fingerprintSourceClass) {
        [recorder skip:@"edge-gesture-routes-bottom-slide-to-fingerprint-slide-in"
                reason:@"LATFingerprintSensorEventSource was not loaded"];
        return;
    }

    LATFingerprintSensorEventSource *fingerprintSource = [[fingerprintSourceClass alloc] init];
    [fingerprintSource start];
    LATEdgeGestureEventSource *fingerprintEdgeSource = [[sourceClass alloc] init];
    fingerprintEdgeSource.fingerprintSensorEventSource = fingerprintSource;
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
    NSString *fingerprintSlideEventName =
        [fingerprintEdgeSource la_testingNoteTouchSnapshots:[self edgeGestureSnapshotsWithLocations:@[
                                                   [self edgeGesturePointWithX:200.0 y:700.0]
                                               ]
                                                                                           phase:1]
                                                 bounds:bounds
                                              timestamp:0.4];
    [fingerprintSource la_testingResolvePendingSinglePress];
    [recorder expect:[fingerprintSlideEventName isEqualToString:LAEventNameFingerprintSensorPressSingleAndSlideIn] &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingleAndSlideIn
                                           activator:activator] == 1 &&
                     [self dispatchCountForEventName:LAEventNameSlideInFromBottom activator:activator] == 0 &&
                     [self dispatchCountForEventName:LAEventNameFingerprintSensorPressSingle activator:activator] == 0
            caseName:@"edge-gesture-routes-bottom-slide-to-fingerprint-slide-in"
              reason:@"Bottom slide after fingerprint press did not route to the fingerprint slide-in event"];
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

+ (NSArray<NSString *> *)forceTouchEventNames {
    return @[
        @"libactivator.force-touch.screen-bottom",
        @"libactivator.force-touch.screen-bottom-left",
        @"libactivator.force-touch.screen-bottom-right",
        @"libactivator.force-touch.screen-left",
        @"libactivator.force-touch.screen-right",
        @"libactivator.force-touch.statusbar",
    ];
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

@end
