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
    NSString *missingURLName = @"libactivator.test.url.missing";
    NSString *invalidURLName = @"libactivator.test.url.invalid";
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
    [recorder expect:!openFailureEvent.handled && openCount == 3
            caseName:@"url-open-failure-unhandled"
              reason:@"URL action marked the event handled when the opener failed"];

    id testURLListener = [[(Class)urlActionClass alloc] init];
    [activator registerListener:testURLListener forName:missingURLName];
    [urlActionClass resetTestingState];
    [urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return YES;
    }];
    LAEvent *missingURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:missingURLEvent toListenerWithName:missingURLName];
    [recorder expect:!missingURLEvent.handled && [urlActionClass testingLastOpenedURL] == nil
            caseName:@"missing-url-metadata-unhandled"
              reason:@"URL action handled an event with no URL metadata"];

    [activator registerListener:testURLListener forName:invalidURLName];
    [urlActionClass setTestingURLMetadata:@{@"url" : @"not a valid absolute URL"} forListenerName:invalidURLName];
    LAEvent *invalidURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:invalidURLEvent toListenerWithName:invalidURLName];
    [recorder expect:!invalidURLEvent.handled && [urlActionClass testingLastOpenedURL] == nil
            caseName:@"invalid-url-metadata-unhandled"
              reason:@"URL action handled an event with invalid URL metadata"];

    [urlActionClass resetTestingState];
}

@end

