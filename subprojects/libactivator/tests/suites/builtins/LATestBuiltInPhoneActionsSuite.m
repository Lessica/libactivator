//
//  LATestBuiltInPhoneActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInPhoneActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInPhoneActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInPhoneActions"];

    Class<LATestSelectorBackedBuiltInListener> phoneActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATPhoneActionListener");
    [recorder expect:phoneActionClass != Nil
            caseName:@"phone-action-class-available"
              reason:@"LATPhoneActionListener class was not loaded in SpringBoard"];
    if (!phoneActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.phone.answer-call" : @"answerCall",
        @"libactivator.phone.disconnect-call" : @"answerCall",
        @"libactivator.phone.favorites" : @"showPhoneFavorites",
        @"libactivator.phone.recents" : @"showPhoneRecents",
        @"libactivator.phone.contacts" : @"showPhoneContacts",
        @"libactivator.phone.keypad" : @"showPhoneKeypad",
        @"libactivator.phone.voicemail" : @"showPhoneVoicemail",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[phoneActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"phone-action-allowlist-count"
              reason:@"Phone action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"phone-action-registered-%@", listenerName]
                  reason:@"Phone action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[phoneActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"phone-action-selector-%@", listenerName]
                  reason:@"Phone action selector mapping did not match bundled metadata"];
    }

    [recorder expect:![activator hasListenerWithName:@"libactivator.phone"]
            caseName:@"phone-group-name-not-registered"
              reason:@"Phone group name was registered as an action listener"];
}

@end
