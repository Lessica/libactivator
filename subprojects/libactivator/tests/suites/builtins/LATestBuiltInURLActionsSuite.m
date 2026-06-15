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

    Class<LATestURLActionListener> urlActionClass =
        (Class<LATestURLActionListener>)NSClassFromString(@"LATURLActionListener");
    [recorder expect:urlActionClass != Nil
            caseName:@"url-action-class-available"
              reason:@"LATURLActionListener class was not loaded in SpringBoard"];
    if (!urlActionClass) {
        return;
    }

    NSSet<NSString *> *hardcodedPhoneURLNames = [NSSet setWithArray:@[
        @"libactivator.phone.favorites",
        @"libactivator.phone.recents",
        @"libactivator.phone.contacts",
        @"libactivator.phone.keypad",
        @"libactivator.phone.voicemail",
    ]];
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[urlActionClass supportedListenerNames]];
    [recorder expect:supportedNames.count == 49
            caseName:@"url-action-allowlist-count"
              reason:@"URL action allowlist did not match the expected count"];

    BOOL allSupportedNamesRegistered = YES;
    BOOL allSupportedNamesHaveRequiredMetadata = YES;
    for (NSString *listenerName in supportedNames) {
        allSupportedNamesRegistered = allSupportedNamesRegistered && [activator hasListenerWithName:listenerName];

        if ([hardcodedPhoneURLNames containsObject:listenerName]) {
            id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
            allSupportedNamesHaveRequiredMetadata = allSupportedNamesHaveRequiredMetadata &&
                                                    [selector isKindOfClass:NSString.class] && [selector length] > 0;
        } else {
            id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
            id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
            BOOL hasURL = [url isKindOfClass:NSString.class] && [url length] > 0;
            BOOL hasURLs = [urls isKindOfClass:NSArray.class] && [urls count] > 0;
            allSupportedNamesHaveRequiredMetadata = allSupportedNamesHaveRequiredMetadata && (hasURL || hasURLs);
        }
    }
    [recorder expect:allSupportedNamesRegistered
            caseName:@"url-action-supported-names-registered"
              reason:@"At least one supported URL action was not registered"];
    [recorder expect:allSupportedNamesHaveRequiredMetadata
            caseName:@"url-action-supported-names-have-required-metadata"
              reason:@"At least one supported URL action has no required metadata"];

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

    [recorder expect:[supportedNames containsObject:@"libactivator.phone.recents"] &&
                     [activator hasListenerWithName:@"libactivator.phone.recents"]
            caseName:@"url-action-phone-tab-registered"
              reason:@"Phone tab URL action was not registered by LATURLActionListener"];
    [recorder expect:[urlActionClass listenerNameHasRequiredMetadata:@"libactivator.phone.recents" activator:activator]
            caseName:@"url-action-hardcoded-phone-selector-metadata"
              reason:@"Hardcoded Phone URL action selector metadata did not match the expected selector"];

    id<LATestURLActionListener> urlAction = [[(Class)urlActionClass alloc] init];
    NSString *phoneURL = [urlAction urlStringForListenerName:@"libactivator.phone.recents" activator:activator];
    [recorder expect:[phoneURL isEqualToString:@"mobilephone-recents:"]
            caseName:@"url-action-hardcoded-phone-url"
              reason:@"Hardcoded Phone URL action did not resolve to the expected URL"];

    NSString *keypadURL = [urlAction urlStringForListenerName:@"libactivator.phone.keypad" activator:activator];
    [recorder expect:[keypadURL isEqualToString:@"mobilephone-recents:keypad"]
            caseName:@"url-action-hardcoded-phone-keypad-url"
              reason:@"Hardcoded Phone keypad URL action did not resolve to the expected URL"];

    NSString *selectedVersionedURL = [urlAction urlStringInURLsValue:@[
        @"prefs:root=General",
        @0,
        @"prefs:root=Bluetooth",
        @(kCFCoreFoundationVersionNumber + 1000.0),
        @"prefs:root=Future",
    ]];
    [recorder expect:[selectedVersionedURL isEqualToString:@"prefs:root=Bluetooth"]
            caseName:@"url-action-versioned-url-selection"
              reason:@"Versioned URL metadata did not select the newest eligible URL"];

    LAEvent *unsupportedEvent = [LAEvent eventWithName:@"libactivator.test.built-in.url" mode:LAEventModeSpringBoard];
    [urlAction activator:activator receiveEvent:unsupportedEvent forListenerName:@"libactivator.test.url.unsupported"];
    [recorder expect:!unsupportedEvent.handled
            caseName:@"url-action-unsupported-name-unhandled"
              reason:@"Unsupported URL action listener name consumed the event"];

    [recorder expect:![activator hasListenerWithName:@"libactivator.settings.brightness"]
            caseName:@"url-action-obsolete-name-not-registered"
              reason:@"Obsolete URL action was registered"];
}

@end
