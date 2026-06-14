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

    [self runStatusBarRecognizerTestsWithRecorder:recorder activator:activator];
    [self runEdgeGestureClassifierTestsWithRecorder:recorder];
}

+ (NSUInteger)dispatchCountForEventName:(NSString *)eventName activator:(LAActivator *)activator {
    return [activator.la_eventDispatchCounts[eventName] unsignedIntegerValue];
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

    CGRect deviceBounds = CGRectMake(0.0, 0.0, 414.0, 736.0);
    NSArray<NSDictionary<NSString *, id> *> *observedSideCases = @[
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-left-top",
            @"EventName" : @"libactivator.two-finger-slide-in.left-top",
            @"Start" : @[ [self edgeGesturePointWithX:41.3 y:32.3], [self edgeGesturePointWithX:47.3 y:112.7] ],
            @"Move" : @[ [self edgeGesturePointWithX:74.0 y:32.3], [self edgeGesturePointWithX:75.3 y:112.7] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-left",
            @"EventName" : LAEventNameTwoFingerSlideInFromLeft,
            @"Start" : @[ [self edgeGesturePointWithX:39.3 y:413.7], [self edgeGesturePointWithX:36.3 y:323.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:74.0 y:413.7], [self edgeGesturePointWithX:75.3 y:323.3] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-left-bottom",
            @"EventName" : @"libactivator.two-finger-slide-in.left-bottom",
            @"Start" : @[ [self edgeGesturePointWithX:35.0 y:626.7], [self edgeGesturePointWithX:39.0 y:705.3] ],
            @"Move" : @[ [self edgeGesturePointWithX:71.3 y:703.3], [self edgeGesturePointWithX:68.3 y:626.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-right-top",
            @"EventName" : @"libactivator.two-finger-slide-in.right-top",
            @"Start" : @[ [self edgeGesturePointWithX:379.7 y:33.7], [self edgeGesturePointWithX:379.7 y:103.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:337.7 y:104.0], [self edgeGesturePointWithX:330.7 y:35.7] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-right",
            @"EventName" : LAEventNameTwoFingerSlideInFromRight,
            @"Start" : @[ [self edgeGesturePointWithX:375.7 y:312.3], [self edgeGesturePointWithX:378.3 y:381.7] ],
            @"Move" : @[ [self edgeGesturePointWithX:346.3 y:314.0], [self edgeGesturePointWithX:352.7 y:383.3] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-two-finger-right-bottom",
            @"EventName" : @"libactivator.two-finger-slide-in.right-bottom",
            @"Start" : @[ [self edgeGesturePointWithX:377.3 y:624.3], [self edgeGesturePointWithX:377.3 y:692.7] ],
            @"Move" : @[ [self edgeGesturePointWithX:345.0 y:692.7], [self edgeGesturePointWithX:341.0 y:623.3] ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in observedSideCases) {
        NSString *eventName = [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                                          bounds:deviceBounds
                                                                  startLocations:testCase[@"Start"]
                                                                   moveLocations:testCase[@"Move"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSArray<NSDictionary<NSString *, id> *> *observedSingleFingerSideCases = @[
        @{
            @"Case" : @"edge-gesture-classifies-observed-single-finger-left-top",
            @"EventName" : @"libactivator.slide-in.left-top",
            @"Start" : @[ [self edgeGesturePointWithX:14.3 y:46.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:63.0 y:46.0] ],
        },
        @{
            @"Case" : @"edge-gesture-classifies-observed-single-finger-right-bottom",
            @"EventName" : @"libactivator.slide-in.right-bottom",
            @"Start" : @[ [self edgeGesturePointWithX:400.7 y:696.0] ],
            @"Move" : @[ [self edgeGesturePointWithX:351.0 y:696.0] ],
        },
    ];

    for (NSDictionary<NSString *, id> *testCase in observedSingleFingerSideCases) {
        NSString *eventName = [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                                          bounds:deviceBounds
                                                                  startLocations:testCase[@"Start"]
                                                                   moveLocations:testCase[@"Move"]];
        NSString *expectedEventName = testCase[@"EventName"];
        [recorder expect:[eventName isEqualToString:expectedEventName]
                caseName:testCase[@"Case"]
                  reason:[NSString stringWithFormat:@"Expected %@ but classified %@", expectedEventName, eventName]];
    }

    NSString *nonEdgeEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:bounds
                                            startLocations:@[ [self edgeGesturePointWithX:200.0 y:400.0] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:2.0 y:400.0] ]];
    [recorder expect:nonEdgeEventName == nil
            caseName:@"edge-gesture-ignores-non-edge-start"
              reason:@"A gesture that began away from the edge was classified after moving to the edge"];

    NSString *wideSingleFingerLeftEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:41.3 y:368.3] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:74.0 y:368.3] ]];
    NSString *wideSingleFingerRightEventName =
        [self classifiedEdgeGestureEventNameWithClassifier:classifier
                                                    bounds:deviceBounds
                                            startLocations:@[ [self edgeGesturePointWithX:377.3 y:368.3] ]
                                             moveLocations:@[ [self edgeGesturePointWithX:345.0 y:368.3] ]];
    [recorder expect:wideSingleFingerLeftEventName == nil && wideSingleFingerRightEventName == nil
            caseName:@"edge-gesture-keeps-single-finger-side-edge-band-narrow"
              reason:@"Single-finger side gestures used the widened two-finger side edge band"];

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

+ (NSString *)classifiedEdgeGestureEventNameWithClassifier:(LATEdgeGestureClassifier *)classifier
                                                    bounds:(CGRect)bounds
                                            startLocations:(NSArray<NSValue *> *)startLocations
                                             moveLocations:(NSArray<NSValue *> *)moveLocations {
    [classifier reset];
    [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:startLocations phase:0]
                                  bounds:bounds
                               timestamp:0.0];
    return [classifier updateWithTouchSnapshots:[self edgeGestureSnapshotsWithLocations:moveLocations phase:1]
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

@end
