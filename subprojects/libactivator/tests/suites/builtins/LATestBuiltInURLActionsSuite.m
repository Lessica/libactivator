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
    [recorder expect:supportedNames.count == 55
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

    id brightnessURL = [activator infoDictionaryValueOfKey:@"url"
                                       forListenerWithName:@"libactivator.settings.brightness"];
    id brightnessWallpaperURL = [activator infoDictionaryValueOfKey:@"url"
                                                forListenerWithName:@"libactivator.settings.brightness-and-wallpaper"];
    id equalizerURL = [activator infoDictionaryValueOfKey:@"url"
                                      forListenerWithName:@"libactivator.settings.equalizer"];
    [recorder expect:[brightnessURL isEqual:@"prefs:root=DISPLAY"] &&
                     [brightnessWallpaperURL isEqual:@"prefs:root=Wallpaper"] &&
                     [equalizerURL isEqual:@"prefs:root=MUSIC&path=com.apple.Music:EQ"]
            caseName:@"url-action-restored-settings-url-metadata"
              reason:@"Restored Settings URL action metadata did not match the expected URLs"];

    id bedtimeURL = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:@"libactivator.clock.bedtime"];
    id networkURL = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:@"libactivator.settings.network"];
    id usageURL = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:@"libactivator.settings.usage"];
    [recorder expect:[bedtimeURL isEqual:@"clock-sleep-alarm:default"] && [networkURL isEqual:@"prefs:root=WIFI"] &&
                     [usageURL isEqual:@"prefs:root=General&path=STORAGE_MGMT#MANAGE"]
            caseName:@"url-action-restored-clock-and-network-url-metadata"
              reason:@"Restored Clock or network Settings URL action metadata did not match the expected URLs"];

    [recorder expect:[supportedNames containsObject:@"libactivator.phone.recents"] &&
                     [activator hasListenerWithName:@"libactivator.phone.recents"]
            caseName:@"url-action-phone-tab-registered"
              reason:@"Phone tab URL action was not registered by LATURLActionListener"];
    [recorder expect:[urlActionClass listenerNameHasRequiredMetadata:@"libactivator.phone.recents" activator:activator]
            caseName:@"url-action-hardcoded-phone-selector-metadata"
              reason:@"Hardcoded Phone URL action selector metadata did not match the expected selector"];

    id<LATestURLActionListener> urlAction =
        (id<LATestURLActionListener>)[activator listenerForName:@"libactivator.clock.timer"];
    [recorder expect:[urlAction isKindOfClass:(Class)urlActionClass]
            caseName:@"url-action-production-instance-available"
              reason:@"The registered URL action listener does not use LATURLActionListener"];
    NSString *phoneURL = [urlAction urlStringForListenerName:@"libactivator.phone.recents" activator:activator];
    [recorder expect:[phoneURL isEqualToString:@"mobilephone-recents:"]
            caseName:@"url-action-hardcoded-phone-url"
              reason:@"Hardcoded Phone URL action did not resolve to the expected URL"];

    NSString *keypadURL = [urlAction urlStringForListenerName:@"libactivator.phone.keypad" activator:activator];
    [recorder expect:[keypadURL isEqualToString:@"mobilephone-recents:keypad"]
            caseName:@"url-action-hardcoded-phone-keypad-url"
              reason:@"Hardcoded Phone keypad URL action did not resolve to the expected URL"];

    BOOL allSupportedNamesResolveURL = YES;
    for (NSString *listenerName in supportedNames) {
        allSupportedNamesResolveURL = allSupportedNamesResolveURL && [urlAction URLForListenerName:listenerName
                                                                                         activator:activator] != nil;
    }
    [recorder expect:allSupportedNamesResolveURL
            caseName:@"url-action-supported-names-resolve-handled-url"
              reason:@"At least one supported URL action did not resolve a URL that can be handled"];

    [recorder expect:[urlAction URLForListenerName:@"libactivator.clock.timer" activator:nil] == nil
            caseName:@"url-action-missing-metadata-unhandled"
              reason:@"Metadata-backed URL action resolved without URL metadata"];
    [recorder expect:[urlAction URLForListenerName:@"libactivator.phone.recents" activator:nil] != nil
            caseName:@"url-action-hardcoded-phone-url-handled-without-metadata"
              reason:@"Hardcoded Phone URL action should not depend on URL metadata"];

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

    [recorder expect:[activator hasListenerWithName:@"libactivator.settings.brightness"] &&
                     [activator hasListenerWithName:@"libactivator.settings.brightness-and-wallpaper"] &&
                     [activator hasListenerWithName:@"libactivator.settings.equalizer"] &&
                     [activator hasListenerWithName:@"libactivator.clock.bedtime"] &&
                     [activator hasListenerWithName:@"libactivator.settings.network"] &&
                     [activator hasListenerWithName:@"libactivator.settings.usage"]
            caseName:@"url-action-restored-settings-names-registered"
              reason:@"Restored Settings URL action was not registered"];
}

@end
