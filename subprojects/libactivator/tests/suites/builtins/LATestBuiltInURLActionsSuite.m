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

    NSSet<NSString *> *hardcodedPhoneURLNames = [NSSet setWithArray:@[
        @"libactivator.phone.favorites",
        @"libactivator.phone.recents",
        @"libactivator.phone.contacts",
        @"libactivator.phone.voicemail",
    ]];
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[urlActionClass supportedListenerNames]];
    [recorder expect:supportedNames.count == 48
            caseName:@"url-action-allowlist-count"
              reason:@"URL action allowlist did not match the expected count"];

    BOOL allSupportedNamesRegistered = YES;
    BOOL allSupportedNamesHaveRequiredMetadata = YES;
    for (NSString *listenerName in supportedNames) {
        allSupportedNamesRegistered = allSupportedNamesRegistered && [activator hasListenerWithName:listenerName];

        if ([hardcodedPhoneURLNames containsObject:listenerName]) {
            id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
            allSupportedNamesHaveRequiredMetadata =
                allSupportedNamesHaveRequiredMetadata && [selector isKindOfClass:NSString.class] && [selector length] > 0;
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

    [recorder expect:![activator hasListenerWithName:@"libactivator.settings.brightness"]
            caseName:@"url-action-obsolete-name-not-registered"
              reason:@"Obsolete URL action was registered"];
    [recorder expect:![activator hasListenerWithName:@"libactivator.phone.keypad"]
            caseName:@"url-action-obsolete-phone-keypad-not-registered"
              reason:@"Obsolete Phone keypad URL action was registered"];
}

@end
