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

    Class<LATestMediaActionListenerTesting> mediaActionClass =
        (Class<LATestMediaActionListenerTesting>)NSClassFromString(@"LATMediaActionListener");
    [recorder expect:mediaActionClass != Nil
            caseName:@"media-action-class-available"
              reason:@"LATMediaActionListener class was not loaded in SpringBoard"];
    if (!mediaActionClass) {
        return;
    }

    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *expectedCommands = @{
        @"libactivator.ipod.toggle-playback" :
            @{@"selector" : @"togglePlayback", @"page" : @(0x0C), @"usage" : @(0xCD)},
        @"libactivator.ipod.pause-playback" : @{@"selector" : @"pauseMedia", @"page" : @(0x0C), @"usage" : @(0xB1)},
        @"libactivator.ipod.resume-playback" : @{@"selector" : @"playMedia", @"page" : @(0x0C), @"usage" : @(0xB0)},
        @"libactivator.ipod.next-track" : @{@"selector" : @"nextTrack", @"page" : @(0x0C), @"usage" : @(0xB5)},
        @"libactivator.ipod.previous-track" : @{@"selector" : @"previousTrack", @"page" : @(0x0C), @"usage" : @(0xB6)},
        @"libactivator.audio.increase-volume" :
            @{@"selector" : @"increaseVolume", @"page" : @(0x0C), @"usage" : @(0xE9)},
        @"libactivator.audio.decrease-volume" :
            @{@"selector" : @"decreaseVolume", @"page" : @(0x0C), @"usage" : @(0xEA)},
    };
    NSDictionary<NSString *, NSString *> *expectedNonHIDSelectors = @{
        @"libactivator.audio.show-volume-bar" : @"showVolumeBar",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[mediaActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedCommands.count + expectedNonHIDSelectors.count
            caseName:@"media-action-allowlist-count"
              reason:@"Media action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedCommands) {
        NSDictionary *expectedCommand = expectedCommands[listenerName];
        [recorder expect:[supportedNames containsObject:listenerName]
                caseName:[NSString stringWithFormat:@"media-action-allowlist-%@", listenerName]
                  reason:@"Media action allowlist is missing an expected listener name"];
        [recorder expect:[[mediaActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedCommand[@"selector"]]
                caseName:[NSString stringWithFormat:@"media-action-selector-%@", listenerName]
                  reason:@"Media action selector mapping did not match bundled metadata"];
    }
    for (NSString *listenerName in expectedNonHIDSelectors) {
        [recorder expect:[supportedNames containsObject:listenerName]
                caseName:[NSString stringWithFormat:@"media-action-allowlist-%@", listenerName]
                  reason:@"Media action allowlist is missing an expected listener name"];
        [recorder expect:[[mediaActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedNonHIDSelectors[listenerName]]
                caseName:[NSString stringWithFormat:@"media-action-selector-%@", listenerName]
                  reason:@"Media action selector mapping did not match bundled metadata"];
    }

    [recorder expect:[activator hasListenerWithName:@"libactivator.audio.show-volume-bar"]
            caseName:@"media-volume-hud-action-registered"
              reason:@"Volume HUD media action was not registered"];
    [recorder expect:![activator hasListenerWithName:@"libactivator.ipod.music-controls"] &&
                     ![activator hasListenerWithName:@"libactivator.audio.launch-playing-app"]
            caseName:@"media-ui-actions-not-registered"
              reason:@"Unsupported media UI or now-playing actions were registered"];

    NSString *eventName = @"libactivator.test.built-in.media";
    NSString *toggleName = @"libactivator.ipod.toggle-playback";
    NSString *showVolumeBarName = @"libactivator.audio.show-volume-bar";
    NSString *unknownName = @"libactivator.test.media.unknown";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    [activator registerEventDataSource:dataSource forEventName:eventName];

    __block NSInteger sendCount = 0;
    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        sendCount += 1;
        return YES;
    }];

    for (NSString *listenerName in expectedCommands) {
        NSDictionary *expectedCommand = expectedCommands[listenerName];
        LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
        [activator sendEvent:event toListenerWithName:listenerName];
        [recorder expect:event.handled
                caseName:[NSString stringWithFormat:@"media-action-handles-%@", listenerName]
                  reason:@"Media action did not mark a successfully sent event handled"];
        [recorder expect:[[mediaActionClass testingLastSentListenerName] isEqualToString:listenerName] &&
                         [mediaActionClass testingLastSentPage] == [expectedCommand[@"page"] unsignedIntValue] &&
                         [mediaActionClass testingLastSentUsage] == [expectedCommand[@"usage"] unsignedIntValue]
                caseName:[NSString stringWithFormat:@"media-action-command-%@", listenerName]
                  reason:@"Media action sent the wrong HID page or usage"];
    }
    [recorder expect:sendCount == (NSInteger)expectedCommands.count
            caseName:@"media-action-send-count"
              reason:@"Media action sender was not called once per expected command"];
    NSArray<NSString *> *sentPhases = [mediaActionClass testingSentPhases];
    BOOL sentDownUpPairs = sentPhases.count == expectedCommands.count * 2;
    for (NSUInteger index = 0; sentDownUpPairs && index < sentPhases.count; index += 2) {
        sentDownUpPairs = [sentPhases[index] isEqualToString:@"down"] && [sentPhases[index + 1] isEqualToString:@"up"];
    }
    [recorder expect:sentDownUpPairs
            caseName:@"media-action-down-up-order"
              reason:@"Media action did not send a down/up HID event pair"];

    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        return YES;
    }];
    LAEvent *showVolumeBarEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:showVolumeBarEvent toListenerWithName:showVolumeBarName];
    NSArray<NSString *> *showVolumeBarPhases = [mediaActionClass testingSentPhases];
    [recorder
          expect:showVolumeBarEvent.handled &&
                 [[mediaActionClass testingLastSentListenerName] isEqualToString:showVolumeBarName] &&
                 [mediaActionClass testingLastSentPage] == 0 && [mediaActionClass testingLastSentUsage] == 0 &&
                 showVolumeBarPhases.count == 1 && [showVolumeBarPhases.firstObject isEqualToString:@"volume-hud"]
        caseName:@"media-volume-hud-action-handles"
          reason:@"Volume HUD media action did not use the presenter path"];

    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        return NO;
    }];
    LAEvent *failureEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:failureEvent toListenerWithName:toggleName];
    [recorder expect:!failureEvent.handled
            caseName:@"media-action-send-failure-unhandled"
              reason:@"Media action marked the event handled when HID sender failed"];

    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        return NO;
    }];
    LAEvent *showVolumeBarFailureEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:showVolumeBarFailureEvent toListenerWithName:showVolumeBarName];
    [recorder expect:!showVolumeBarFailureEvent.handled
            caseName:@"media-volume-hud-action-failure-unhandled"
              reason:@"Volume HUD media action marked the event handled when presenter failed"];

    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSelector:@"wrongSelector" forListenerName:toggleName];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        return YES;
    }];
    LAEvent *mismatchedSelectorEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:mismatchedSelectorEvent toListenerWithName:toggleName];
    [recorder expect:!mismatchedSelectorEvent.handled && [mediaActionClass testingLastSentListenerName] == nil
            caseName:@"media-action-selector-mismatch-unhandled"
              reason:@"Media action handled an event with mismatched selector metadata"];

    id unknownMediaListener = [[(Class)mediaActionClass alloc] init];
    [activator registerListener:unknownMediaListener forName:unknownName];
    [mediaActionClass resetTestingState];
    [mediaActionClass setTestingSendHandler:^BOOL(NSString *listenerName, uint32_t page, uint32_t usage) {
        return YES;
    }];
    LAEvent *unknownEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:unknownEvent toListenerWithName:unknownName];
    [recorder expect:!unknownEvent.handled && [mediaActionClass testingLastSentListenerName] == nil
            caseName:@"media-action-unknown-name-unhandled"
              reason:@"Media action handled an unknown listener name"];

    [mediaActionClass resetTestingState];
}

@end

