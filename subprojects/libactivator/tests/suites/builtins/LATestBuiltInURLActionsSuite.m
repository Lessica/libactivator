//
//  LATestBuiltInURLActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInURLActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInURLActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInURLActions"];

    Class<LATestURLActionListenerTesting> urlActionClass =
        (Class<LATestURLActionListenerTesting>)NSClassFromString(@"LATURLActionListener");
    [recorder expect:urlActionClass != Nil
            caseName:@"url-action-class-available"
              reason:@"LATURLActionListener class was not loaded in SpringBoard"];
    if (!urlActionClass) {
        return;
    }

    NSString *eventName = @"libactivator.test.built-in.url";
    NSString *singleURLName = @"libactivator.clock.timer";
    NSString *versionedURLName = @"libactivator.settings.bluetooth";
    NSString *unknownURLName = @"libactivator.test.url.unknown";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    __block NSInteger openCount = 0;
    [activator registerEventDataSource:dataSource forEventName:eventName];

    [urlActionClass resetTestingState];
    [urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return YES;
    }];

    LAEvent *singleURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:singleURLEvent toListenerWithName:singleURLName];
    NSURL *singleURL = [urlActionClass testingLastOpenedURL];
    NSString *singleListenerName = [urlActionClass testingLastOpenedListenerName];
    [recorder expect:singleURLEvent.handled && openCount == 1
            caseName:@"single-url-handles-event"
              reason:@"URL action with single url metadata did not handle the event"];
    [recorder expect:[[singleURL absoluteString] isEqualToString:@"clock-timer:default"] &&
                     [singleListenerName isEqualToString:singleURLName]
            caseName:@"single-url-selection"
              reason:@"URL action did not open the single url metadata value"];

    LAEvent *versionedURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:versionedURLEvent toListenerWithName:versionedURLName];
    NSURL *versionedURL = [urlActionClass testingLastOpenedURL];
    [recorder expect:versionedURLEvent.handled && openCount == 2
            caseName:@"versioned-url-handles-event"
              reason:@"URL action with versioned urls metadata did not handle the event"];
    [recorder expect:[[versionedURL absoluteString] isEqualToString:@"prefs:root=Bluetooth"]
            caseName:@"versioned-url-selection"
              reason:@"URL action did not select the current CoreFoundation URL"];

    [urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return NO;
    }];
    LAEvent *openFailureEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:openFailureEvent toListenerWithName:singleURLName];
    [recorder expect:openFailureEvent.handled && openCount == 3
            caseName:@"url-open-failure-handled"
              reason:@"URL action did not consume the event when the opener failed"];

    id testURLListener = [[(Class)urlActionClass alloc] init];
    [urlActionClass resetTestingState];
    [urlActionClass setTestingURLMetadata:@{} forListenerName:singleURLName];
    LAEvent *missingURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:missingURLEvent toListenerWithName:singleURLName];
    [recorder expect:missingURLEvent.handled && [urlActionClass testingLastOpenedURL] == nil
            caseName:@"missing-url-metadata-handled"
              reason:@"URL action did not consume the event with no URL metadata"];

    [urlActionClass resetTestingState];
    [urlActionClass setTestingURLMetadata:@{@"url" : @"not a valid absolute URL"} forListenerName:singleURLName];
    LAEvent *invalidURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:invalidURLEvent toListenerWithName:singleURLName];
    [recorder expect:invalidURLEvent.handled && [urlActionClass testingLastOpenedURL] == nil
            caseName:@"invalid-url-metadata-handled"
              reason:@"URL action did not consume the event with invalid URL metadata"];

    [activator registerListener:testURLListener forName:unknownURLName];
    [urlActionClass resetTestingState];
    LAEvent *unknownURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:unknownURLEvent toListenerWithName:unknownURLName];
    [recorder expect:!unknownURLEvent.handled && [urlActionClass testingLastOpenedURL] == nil
            caseName:@"unknown-url-action-unhandled"
              reason:@"URL action handled an unsupported listener name"];

    [urlActionClass resetTestingState];
}

@end
