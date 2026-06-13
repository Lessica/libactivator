//
//  LATestBuiltInEventSourcesSuite.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInEventSourcesSuite.h"

@implementation LATestBuiltInEventSourcesSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInEventSources"];

    NSString *nowPlayingInfoChangedEventName = @"libactivator.now-playing.info-changed";
    NSString *nowPlayingPlayingEventName = @"libactivator.now-playing.playing";
    NSString *nowPlayingPausedEventName = @"libactivator.now-playing.paused";
    NSString *lockPressTripleEventName = @"libactivator.lock.press.triple";

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
    [recorder expect:NSClassFromString(@"LATRuntimeStateSource") != Nil
            caseName:@"runtime-state-source-loaded"
              reason:@"LATRuntimeStateSource class was not loaded in SpringBoard"];
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
}

@end
