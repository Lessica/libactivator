//
//  LATestBuiltInEventSourceCompositionSuite.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInEventSourceCompositionSuite.h"

#import "LATBuiltInRegistry.h"
#import "LATButtonEventSource.h"
#import "LATEdgeGestureEventSource.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATForceTouchEventSource.h"
#import "LATLockStateEventSource.h"
#import "LATMediaEventSource.h"
#import "LATMotionEventSource.h"
#import "LATMultiTouchEventSource.h"
#import "LATNetworkEventDataSource.h"
#import "LATNetworkEventSource.h"
#import "LATPowerStateEventSource.h"
#import "LATSpringBoardIconGestureEventSource.h"
#import "LATStatusBarEventSource.h"
#import "LATVolumeHUDTapEventSource.h"
#import "LATestEventSourceFixture.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@implementation LATestBuiltInEventSourceCompositionSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInEventSourceComposition"];

    NSArray<Class> *expectedEventSourceClasses = @[
        LATFingerprintSensorEventSource.class,
        LATLockStateEventSource.class,
        LATPowerStateEventSource.class,
        LATMediaEventSource.class,
        LATMotionEventSource.class,
        LATNetworkEventSource.class,
        LATButtonEventSource.class,
        LATVolumeHUDTapEventSource.class,
        LATForceTouchEventSource.class,
        LATMultiTouchEventSource.class,
        LATSpringBoardIconGestureEventSource.class,
        LATStatusBarEventSource.class,
        LATEdgeGestureEventSource.class,
    ];
    NSArray<Class> *eventSourceClasses = [LATBuiltInRegistry builtInEventSourceClasses];
    BOOL usesUniformInitializer = eventSourceClasses.count == expectedEventSourceClasses.count;
    for (Class eventSourceClass in eventSourceClasses) {
        usesUniformInitializer = usesUniformInitializer &&
                                 [(id)eventSourceClass conformsToProtocol:@protocol(LATEventSource)] &&
                                 [eventSourceClass instancesRespondToSelector:@selector(initWithEventSourceContext:)];
    }
    [recorder expect:usesUniformInitializer && [eventSourceClasses isEqualToArray:expectedEventSourceClasses] &&
                     [NSSet setWithArray:eventSourceClasses].count == eventSourceClasses.count
            caseName:@"built-in-event-source-class-list-is-explicit-and-complete"
              reason:@"The built-in Event Source class list changed order, contains duplicates, or bypasses the "
                     @"uniform initializer"];

    NSString *nowPlayingInfoChangedEventName = LAEventNameNowPlayingInfoChanged;
    NSString *nowPlayingPlayingEventName = LAEventNameNowPlayingPlaying;
    NSString *nowPlayingPausedEventName = LAEventNameNowPlayingPaused;
    NSString *lockPressTripleEventName = LAEventNameLockPressTriple;
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

    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
    LATNetworkEventSource *networkSource =
        [fixture interestedEventSourceOfClass:LATNetworkEventSource.class previousEventSources:@[]];
    LATEventSourceContext *context = [fixture contextWithPreviousEventSources:@[]];
    id provider = [networkSource eventDefinitionProviderForContext:context];
    [recorder expect:[provider isKindOfClass:LATNetworkEventDataSource.class]
            caseName:@"network-event-source-provides-definition-provider"
              reason:@"Network source did not provide its dynamic definition provider through the uniform hook"];

    NSString *configuredNetworkEventName = [LAEventNameNetworkJoinedWiFi
        stringByAppendingFormat:@".libactivator-test-%@", NSUUID.UUID.UUIDString.lowercaseString];
    [networkSource updateConfiguredEventNames:[NSSet setWithObject:configuredNetworkEventName]];
    [recorder expect:[networkSource.eventNames containsObject:LAEventNameNetworkJoinedWiFi] &&
                     [networkSource.eventNames containsObject:configuredNetworkEventName] &&
                     ![activator hasEventWithName:configuredNetworkEventName]
            caseName:@"network-event-source-only-updates-producer-mapping"
              reason:@"Network source producer mapping unexpectedly created an event definition"];
    [networkSource invalidate];

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
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameVolumeDisplayTap]
            caseName:@"volume-hud-tap-event-available"
              reason:@"Volume HUD tap event metadata was not available"];
    [recorder
          expect:[activator eventWithName:LAEventNameVolumeDisplayTap isCompatibleWithMode:LAEventModeSpringBoard] &&
                 [activator eventWithName:LAEventNameVolumeDisplayTap isCompatibleWithMode:LAEventModeApplication] &&
                 [activator eventWithName:LAEventNameVolumeDisplayTap isCompatibleWithMode:LAEventModeLockScreen]
        caseName:@"volume-hud-tap-event-all-modes-compatible"
          reason:@"Volume HUD tap event was not compatible with all event modes"];

    [self runFingerprintSensorAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runForceTouchAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runMultiTouchAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runSpringBoardIconGestureAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runMotionAvailabilityTestsWithRecorder:recorder activator:activator];
    [self runEventSourceCatalogTestsWithRecorder:recorder activator:activator];
}

+ (void)runFingerprintSensorAvailabilityTestsWithRecorder:(LATestRecorder *)recorder
                                                activator:(LAActivator *)activator {
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

+ (void)runMultiTouchAvailabilityTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    NSArray<NSString *> *eventNames = [self multiTouchEventNames];
    for (NSString *eventName in eventNames) {
        [recorder expect:[[activator availableEventNames] containsObject:eventName]
                caseName:[NSString stringWithFormat:@"multi-touch-event-available-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ metadata was not available", eventName]];
        [recorder
              expect:[activator eventWithName:eventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:eventName isCompatibleWithMode:LAEventModeApplication] &&
                     ![activator eventWithName:eventName isCompatibleWithMode:LAEventModeLockScreen]
            caseName:[NSString stringWithFormat:@"multi-touch-event-unlocked-modes-compatible-%@", eventName]
              reason:[NSString stringWithFormat:@"%@ did not match the legacy unlocked-mode compatibility", eventName]];
    }
}

+ (void)runSpringBoardIconGestureAvailabilityTestsWithRecorder:(LATestRecorder *)recorder
                                                     activator:(LAActivator *)activator {
    NSArray<NSString *> *eventNames = [self springBoardIconGestureEventNames];
    for (NSString *eventName in eventNames) {
        [recorder expect:[[activator availableEventNames] containsObject:eventName]
                caseName:[NSString stringWithFormat:@"springboard-icon-gesture-event-available-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ metadata was not available", eventName]];
        [recorder expect:[activator eventWithName:eventName isCompatibleWithMode:LAEventModeSpringBoard] &&
                         ![activator eventWithName:eventName isCompatibleWithMode:LAEventModeApplication] &&
                         ![activator eventWithName:eventName isCompatibleWithMode:LAEventModeLockScreen]
                caseName:[NSString stringWithFormat:@"springboard-icon-gesture-event-springboard-only-%@", eventName]
                  reason:[NSString stringWithFormat:@"%@ did not match the SpringBoard-only compatibility", eventName]];
    }
}

+ (void)runMotionAvailabilityTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder expect:[[activator availableEventNames] containsObject:LAEventNameMotionShake]
            caseName:@"motion-shake-event-available"
              reason:@"Motion shake event metadata was not available"];
    [recorder expect:[activator eventWithName:LAEventNameMotionShake isCompatibleWithMode:LAEventModeSpringBoard] &&
                     [activator eventWithName:LAEventNameMotionShake isCompatibleWithMode:LAEventModeApplication] &&
                     [activator eventWithName:LAEventNameMotionShake isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"motion-shake-event-all-modes-compatible"
              reason:@"Motion shake event was not compatible with all event modes"];
}

+ (void)runEventSourceCatalogTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    LATestEventSourceFixture *fixture = [[LATestEventSourceFixture alloc] initWithActivator:activator];
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
    LATVolumeHUDTapEventSource *volumeHUDTapSource =
        [fixture interestedEventSourceOfClass:LATVolumeHUDTapEventSource.class previousEventSources:@[]];

    [recorder expect:[edgeSource.eventNames containsObject:LAEventNameStatusBarSwipeDown] &&
                     [statusBarSource.eventNames containsObject:LAEventNameStatusBarSwipeDown]
            caseName:@"event-source-catalog-shares-statusbar-swipe-down"
              reason:@"Status bar swipe down was not declared by both real producers"];
    [recorder expect:![edgeSource.eventNames containsObject:LAEventNameFingerprintSensorPressSingleAndSlideIn] &&
                     ![edgeSource.interestEventNames containsObject:LAEventNameFingerprintSensorPressSingleAndSlideIn]
            caseName:@"edge-catalog-excludes-unavailable-fingerprint-composite"
              reason:@"Edge source claimed a fingerprint composite without an injected fingerprint producer"];
    LATFingerprintSensorEventSource *fingerprintSensorSource =
        [fixture interestedEventSourceOfClass:LATFingerprintSensorEventSource.class previousEventSources:@[]];
    LATEdgeGestureEventSource *edgeSourceWithFingerprint =
        [fixture interestedEventSourceOfClass:LATEdgeGestureEventSource.class
                         previousEventSources:@[ fingerprintSensorSource ]];
    [recorder expect:![edgeSourceWithFingerprint.eventNames
                         containsObject:LAEventNameFingerprintSensorPressSingleAndSlideIn] &&
                     [edgeSourceWithFingerprint.interestEventNames
                         containsObject:LAEventNameFingerprintSensorPressSingleAndSlideIn]
            caseName:@"edge-catalog-separates-fingerprint-interest-dependency"
              reason:@"Edge source did not separate its fingerprint dependency from its producer catalog"];
    [recorder expect:[multiTouchSource.eventNames containsObject:LAEventNameThreeFingerTap] &&
                     [multiTouchSource.eventNames containsObject:LAEventNameFiveFingerSpread]
            caseName:@"event-source-catalog-includes-multi-touch"
              reason:@"Multi-touch source did not declare its complete event range"];
    [recorder expect:[springBoardIconSource.eventNames containsObject:LAEventNameSpringBoardPinch] &&
                     [springBoardIconSource.eventNames containsObject:LAEventNameSpringBoardSpread] &&
                     ![springBoardIconSource.eventNames containsObject:LAEventNameSpringBoardIconFlickUp]
            caseName:@"event-source-catalog-excludes-unimplemented-icon-flick"
              reason:@"SpringBoard icon source catalog included events it cannot produce"];
    [recorder expect:edgeSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode &&
                     forceSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode &&
                     multiTouchSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode &&
                     springBoardIconSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode &&
                     statusBarSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode
            caseName:@"event-source-catalog-declares-assignment-aware-policy"
              reason:@"A high-cost Event Source did not declare assignment-aware interest"];
    [recorder expect:[volumeHUDTapSource.eventNames isEqualToSet:[NSSet setWithObject:LAEventNameVolumeDisplayTap]] &&
                     volumeHUDTapSource.interestPolicy == LATEventSourceInterestPolicyAlways
            caseName:@"volume-hud-tap-source-declares-always-on-catalog"
              reason:@"Volume HUD tap source did not match the 1.9.13 always-on recognizer policy"];

    [volumeHUDTapSource invalidate];
    [statusBarSource invalidate];
    [springBoardIconSource invalidate];
    [multiTouchSource invalidate];
    [forceSource invalidate];
    [edgeSourceWithFingerprint invalidate];
    [fingerprintSensorSource invalidate];
    [edgeSource invalidate];
}

+ (NSArray<NSString *> *)forceTouchEventNames {
    return @[
        LAEventNameForceTouchScreenBottom,
        LAEventNameForceTouchScreenBottomLeft,
        LAEventNameForceTouchScreenBottomRight,
        LAEventNameForceTouchScreenLeft,
        LAEventNameForceTouchScreenRight,
        LAEventNameForceTouchStatusBar,
    ];
}

+ (NSArray<NSString *> *)multiTouchEventNames {
    return @[
        LAEventNameThreeFingerTap,
        LAEventNameThreeFingerPinch,
        LAEventNameThreeFingerSpread,
        LAEventNameFourFingerTap,
        LAEventNameFourFingerPinch,
        LAEventNameFourFingerSpread,
        LAEventNameFiveFingerTap,
        LAEventNameFiveFingerPinch,
        LAEventNameFiveFingerSpread,
    ];
}

+ (NSArray<NSString *> *)springBoardIconGestureEventNames {
    return @[
        LAEventNameSpringBoardPinch,
        LAEventNameSpringBoardSpread,
        LAEventNameSpringBoardIconFlickUp,
        LAEventNameSpringBoardIconFlickDown,
        LAEventNameSpringBoardIconFlickLeft,
        LAEventNameSpringBoardIconFlickRight,
    ];
}

@end
