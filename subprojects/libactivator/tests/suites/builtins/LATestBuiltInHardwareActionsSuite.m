//
//  LATestBuiltInHardwareActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInHardwareActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInHardwareActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInHardwareActions"];

    Class<LATestSelectorBackedBuiltInListener> hardwareActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATHardwareActionListener");
    [recorder expect:hardwareActionClass != Nil
            caseName:@"hardware-action-class-available"
              reason:@"LATHardwareActionListener class was not loaded in SpringBoard"];
    if (!hardwareActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.ipod.toggle-playback" : @"togglePlayback",
        @"libactivator.ipod.pause-playback" : @"pauseMedia",
        @"libactivator.ipod.resume-playback" : @"playMedia",
        @"libactivator.ipod.next-track" : @"nextTrack",
        @"libactivator.ipod.previous-track" : @"previousTrack",
        @"libactivator.audio.increase-volume" : @"increaseVolume",
        @"libactivator.audio.decrease-volume" : @"decreaseVolume",
        @"libactivator.system.take-screenshot" : @"takeScreenshot",
        @"libactivator.system.spotlight" : @"spotlight",
        @"libactivator.system.vibrate" : @"vibrate",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[hardwareActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"hardware-action-allowlist-count"
              reason:@"Hardware action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"hardware-action-registered-%@", listenerName]
                  reason:@"Hardware action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[hardwareActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"hardware-action-selector-%@", listenerName]
                  reason:@"Hardware action selector mapping did not match bundled metadata"];
    }
}

@end
