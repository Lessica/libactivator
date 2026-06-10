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

    Class<LATestBuiltInListenerAllowlist> urlActionClass =
        (Class<LATestBuiltInListenerAllowlist>)NSClassFromString(@"LATURLActionListener");
    [recorder expect:urlActionClass != Nil
            caseName:@"url-action-class-available"
              reason:@"LATURLActionListener class was not loaded in SpringBoard"];
    if (!urlActionClass) {
        return;
    }

    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[urlActionClass supportedListenerNames]];
    [recorder expect:supportedNames.count == 44
            caseName:@"url-action-allowlist-count"
              reason:@"URL action allowlist did not match the expected count"];

    BOOL allSupportedNamesRegistered = YES;
    BOOL allSupportedNamesHaveURLMetadata = YES;
    for (NSString *listenerName in supportedNames) {
        allSupportedNamesRegistered = allSupportedNamesRegistered && [activator hasListenerWithName:listenerName];

        id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
        id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
        BOOL hasURL = [url isKindOfClass:NSString.class] && [url length] > 0;
        BOOL hasURLs = [urls isKindOfClass:NSArray.class] && [urls count] > 0;
        allSupportedNamesHaveURLMetadata = allSupportedNamesHaveURLMetadata && (hasURL || hasURLs);
    }
    [recorder expect:allSupportedNamesRegistered
            caseName:@"url-action-supported-names-registered"
              reason:@"At least one supported URL action was not registered"];
    [recorder expect:allSupportedNamesHaveURLMetadata
            caseName:@"url-action-supported-names-have-metadata"
              reason:@"At least one supported URL action has no url or urls metadata"];

    id timerURL = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:@"libactivator.clock.timer"];
    [recorder expect:[timerURL isEqual:@"clock-timer:default"]
            caseName:@"url-action-representative-single-url-metadata"
              reason:@"Representative single URL action metadata did not match bundled resources"];

    id bluetoothURLs = [activator infoDictionaryValueOfKey:@"urls"
                                       forListenerWithName:@"libactivator.settings.bluetooth"];
    [recorder
          expect:[bluetoothURLs isKindOfClass:NSArray.class] && [bluetoothURLs containsObject:@"prefs:root=Bluetooth"]
        caseName:@"url-action-representative-versioned-url-metadata"
          reason:@"Representative versioned URL action metadata did not match bundled resources"];

    [recorder expect:![activator hasListenerWithName:@"libactivator.settings.brightness"]
            caseName:@"url-action-obsolete-name-not-registered"
              reason:@"Obsolete URL action was registered"];
}

@end
