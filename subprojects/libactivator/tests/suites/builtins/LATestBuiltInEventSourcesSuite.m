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
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeUpPressWithMenu]
            caseName:@"volume-up-press-with-menu-event-available"
              reason:@"Volume up press with menu event metadata was not available"];
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeDownPressWithMenu]
            caseName:@"volume-down-press-with-menu-event-available"
              reason:@"Volume down press with menu event metadata was not available"];
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
    [recorder expect:[activator eventWithName:LAEventNameVolumeUpPressWithMenu
                         isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeUpPressWithMenu
                         isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeUpPressWithMenu
                         isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-up-press-with-menu-all-modes-compatible"
              reason:@"Volume up press with menu event was not compatible with all event modes"];
    [recorder expect:[activator eventWithName:LAEventNameVolumeDownPressWithMenu
                         isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameVolumeDownPressWithMenu
                         isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameVolumeDownPressWithMenu
                         isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"volume-down-press-with-menu-all-modes-compatible"
              reason:@"Volume down press with menu event was not compatible with all event modes"];
}

@end
