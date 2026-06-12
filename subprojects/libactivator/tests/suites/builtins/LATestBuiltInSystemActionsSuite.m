//
//  LATestBuiltInSystemActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInSystemActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInSystemActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInSystemActions"];

    Class<LATestSelectorBackedBuiltInListener> systemActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATSystemActionListener");
    [recorder expect:systemActionClass != Nil
            caseName:@"system-action-class-available"
              reason:@"LATSystemActionListener class was not loaded in SpringBoard"];
    if (!systemActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.audio.show-volume-bar" : @"showVolumeBar",
        @"libactivator.audio.launch-playing-app" : @"launchPlayingApp",
        @"libactivator.audio.reset-ringer-state" : @"resetRingerState",
        @"libactivator.audio.mute-ringer" : @"muteRinger",
        @"libactivator.audio.unmute-ringer" : @"unmuteRinger",
        @"libactivator.audio.toggle-ringer-mute" : @"toggleRingerMute",
        @"libactivator.system.first-springboard-page" : @"firstSpringBoardPage",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[systemActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"system-action-allowlist-count"
              reason:@"System action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"system-action-registered-%@", listenerName]
                  reason:@"System action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[systemActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"system-action-selector-%@", listenerName]
                  reason:@"System action selector mapping did not match bundled metadata"];
    }

    [recorder expect:![activator hasListenerWithName:@"libactivator.volume.mute"]
            caseName:@"system-ringer-event-name-not-registered-as-listener"
              reason:@"Legacy event name was registered as a system listener"];

    id<LAListener> systemAction = [[(Class)systemActionClass alloc] init];
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
