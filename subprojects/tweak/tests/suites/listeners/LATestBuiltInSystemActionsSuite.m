//
//  LATestBuiltInSystemActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInSystemActionsSuite.h"

#import "LATSystemActionListener.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@interface LATSystemActionListener (LATestMetadata)
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
@end

@implementation LATestBuiltInSystemActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInSystemActions"];

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.audio.show-volume-bar" : @"showVolumeBar",
        @"libactivator.audio.launch-playing-app" : @"launchPlayingApp",
        @"libactivator.audio.reset-ringer-state" : @"resetRingerState",
        @"libactivator.audio.mute-ringer" : @"muteRinger",
        @"libactivator.audio.unmute-ringer" : @"unmuteRinger",
        @"libactivator.audio.toggle-ringer-mute" : @"toggleRingerMute",
        @"libactivator.system.first-springboard-page" : @"firstSpringBoardPage",
        @"libactivator.lockscreen.show" : @"showLockScreen",
        @"libactivator.lockscreen.dismiss" : @"dismissLockScreen",
        @"libactivator.lockscreen.toggle" : @"toggleLockScreen",
        @"libactivator.system.lock-and-wipe-credentials" : @"wipeCredentials",
        @"libactivator.system.activate-control-center" : @"showControlCenter",
        @"libactivator.ipod.music-controls" : @"musicControls",
        @"libactivator.system.show-now-playing-bar" : @"showNowPlayingBar",
        @"libactivator.system.activate-notification-center" : @"activateNotificationCenter",
        @"libactivator.system.activate-reachability" : @"activateReachability",
        @"libactivator.keyboard.dictation" : @"startDictation",
        @"libactivator.system.activate-switcher" : @"activateSwitcherFromActivator:event:",
        @"libactivator.system.clear-switcher" : @"clearSwitcher",
        @"libactivator.system.edit-screenshot" : @"editScreenshot",
        @"libactivator.system.power-menu" : @"powerDownView",
        @"libactivator.system.previous-app" : @"previousApp",
        @"libactivator.system.respring" : @"respring",
        @"libactivator.system.hard-respring" : @"hardRespring",
        @"libactivator.system.soft-reboot" : @"softReboot",
        @"libactivator.system.safemode" : @"safeMode",
        @"libactivator.system.powerdown" : @"powerDown",
        @"libactivator.system.reboot" : @"reboot",
        @"libactivator.system.haptic.flick" : @"tapticWithActivator:event:listenerName:",
        @"libactivator.system.haptic.tap" : @"tapticWithActivator:event:listenerName:",
        @"libactivator.system.haptic.quirk" : @"tapticWithActivator:event:listenerName:",
        @"libactivator.system.back" : @"goBackWithActivator:event:",
        @"libactivator.system.local-back" : @"localBack",
        @"libactivator.system.rotate.landscape-left" : @"rotateLandscapeLeft",
        @"libactivator.system.rotate.landscape-right" : @"rotateLandscapeRight",
        @"libactivator.system.rotate.portrait" : @"rotatePortrait",
        @"libactivator.system.rotate.portrait-upside-down" : @"rotatePortraitUpsideDown",
        @"libactivator.system.virtual-assistant" : @"activateSiri",
        @"libactivator.system.voice-control" : @"voiceControl",
        @"libactivator.system.wallet" : @"openWallet",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[LATSystemActionListener supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"system-action-allowlist-count"
              reason:@"System action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"system-action-registered-%@", listenerName]
                  reason:@"System action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[LATSystemActionListener expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"system-action-selector-%@", listenerName]
                  reason:@"System action selector mapping did not match bundled metadata"];
    }

    NSDictionary<NSString *, NSNumber *> *expectedTapticTypes = @{
        @"libactivator.system.haptic.flick" : @0,
        @"libactivator.system.haptic.tap" : @1,
        @"libactivator.system.haptic.quirk" : @2,
    };
    for (NSString *listenerName in expectedTapticTypes) {
        id tapticType = [activator infoDictionaryValueOfKey:@"tapticType" forListenerWithName:listenerName];
        NSInteger actualType =
            [tapticType respondsToSelector:@selector(integerValue)] ? [tapticType integerValue] : NSIntegerMin;
        [recorder expect:actualType == expectedTapticTypes[listenerName].integerValue
                caseName:[NSString stringWithFormat:@"system-action-taptic-type-%@", listenerName]
                  reason:@"System action tapticType metadata did not match the 1.9.13 mapping"];
    }

    [recorder expect:[activator listenerWithName:@"libactivator.system.show-now-playing-bar"
                            isCompatibleWithMode:LAEventModeLockScreen]
            caseName:@"system-now-playing-bar-lockscreen-compatible"
              reason:@"Show Now Playing Bar should be assignable at the lock screen"];

    NSArray<NSString *> *nowPlayingControlNames =
        @[ @"libactivator.ipod.music-controls", @"libactivator.system.show-now-playing-bar" ];
    for (NSString *listenerName in nowPlayingControlNames) {
        id needsPoweredDisplay = [activator infoDictionaryValueOfKey:@"needs-powered-display"
                                                 forListenerWithName:listenerName];
        BOOL requiresPoweredDisplay =
            [needsPoweredDisplay respondsToSelector:@selector(boolValue)] && [needsPoweredDisplay boolValue];
        [recorder
              expect:!requiresPoweredDisplay
            caseName:[NSString stringWithFormat:@"system-now-playing-controls-no-powered-display-gate-%@", listenerName]
              reason:@"Now Playing controls should wake the screen internally instead of being gated while blanked"];
    }

    [recorder expect:![activator hasListenerWithName:LAEventNameVolumeMuteOn]
            caseName:@"system-ringer-event-name-not-registered-as-listener"
              reason:@"Legacy event name was registered as a system listener"];

    id<LAListener> systemAction = [activator listenerForName:@"libactivator.audio.show-volume-bar"];
    [recorder expect:[systemAction isKindOfClass:LATSystemActionListener.class]
            caseName:@"system-action-production-instance-available"
              reason:@"The registered system action listener does not use LATSystemActionListener"];
    LAEvent *unsupportedEvent = [LAEvent eventWithName:@"libactivator.test.built-in.system"
                                                  mode:LAEventModeSpringBoard];
    [systemAction activator:activator
               receiveEvent:unsupportedEvent
            forListenerName:@"libactivator.test.system.unsupported"];
    [recorder expect:!unsupportedEvent.handled
            caseName:@"system-action-unsupported-name-unhandled"
              reason:@"Unsupported system action listener name consumed the event"];
}

@end
