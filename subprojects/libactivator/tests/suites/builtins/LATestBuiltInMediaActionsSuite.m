//
//  LATestBuiltInMediaActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInMediaActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInMediaActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInMediaActions"];

    Class<LATestSelectorBackedBuiltInListener> mediaActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATMediaActionListener");
    [recorder expect:mediaActionClass != Nil
            caseName:@"media-action-class-available"
              reason:@"LATMediaActionListener class was not loaded in SpringBoard"];
    if (!mediaActionClass) {
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
        @"libactivator.audio.show-volume-bar" : @"showVolumeBar",
    };
    NSString *launchPlayingAppName = @"libactivator.audio.launch-playing-app";
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[mediaActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count + 1
            caseName:@"media-action-allowlist-count"
              reason:@"Media action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"media-action-registered-%@", listenerName]
                  reason:@"Media action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[mediaActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"media-action-selector-%@", listenerName]
                  reason:@"Media action selector mapping did not match bundled metadata"];
    }

    id launchTitle = [activator infoDictionaryValueOfKey:@"title" forListenerWithName:launchPlayingAppName];
    [recorder expect:[supportedNames containsObject:launchPlayingAppName] &&
                     [activator hasListenerWithName:launchPlayingAppName] &&
                     [mediaActionClass expectedSelectorForListenerName:launchPlayingAppName] == nil &&
                     [launchTitle isKindOfClass:NSString.class] && [launchTitle length] > 0
            caseName:@"media-now-playing-application-registered"
              reason:@"Now-playing application media action registration or metadata was invalid"];

    [recorder expect:![activator hasListenerWithName:@"libactivator.ipod.music-controls"]
            caseName:@"media-music-controls-not-registered"
              reason:@"Obsolete media controls action was registered"];
}

@end
