//
//  LATestBuiltInRingerActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInRingerActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInRingerActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInRingerActions"];

    Class<LATestSelectorBackedBuiltInListener> ringerActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATRingerActionListener");
    [recorder expect:ringerActionClass != Nil
            caseName:@"ringer-action-class-available"
              reason:@"LATRingerActionListener class was not loaded in SpringBoard"];
    if (!ringerActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.audio.reset-ringer-state" : @"resetRingerState",
        @"libactivator.audio.mute-ringer" : @"muteRinger",
        @"libactivator.audio.unmute-ringer" : @"unmuteRinger",
        @"libactivator.audio.toggle-ringer-mute" : @"toggleRingerMute",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[ringerActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"ringer-action-allowlist-count"
              reason:@"Ringer action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"ringer-action-registered-%@", listenerName]
                  reason:@"Ringer action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[ringerActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"ringer-action-selector-%@", listenerName]
                  reason:@"Ringer action selector mapping did not match bundled metadata"];
    }

    [recorder expect:![activator hasListenerWithName:@"libactivator.volume.mute"]
            caseName:@"ringer-event-name-not-registered-as-listener"
              reason:@"Legacy event name was registered as a ringer listener"];
}

@end
