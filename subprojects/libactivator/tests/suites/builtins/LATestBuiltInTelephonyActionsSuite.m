//
//  LATestBuiltInTelephonyActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInTelephonyActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInTelephonyActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInTelephonyActions"];

    Class<LATestSelectorBackedBuiltInListener> telephonyActionClass =
        (Class<LATestSelectorBackedBuiltInListener>)NSClassFromString(@"LATTelephonyActionListener");
    [recorder expect:telephonyActionClass != Nil
            caseName:@"telephony-action-class-available"
              reason:@"LATTelephonyActionListener class was not loaded in SpringBoard"];
    if (!telephonyActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.phone.answer-call" : @"answerCall",
        @"libactivator.phone.disconnect-call" : @"disconnectCall",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[telephonyActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"telephony-action-allowlist-count"
              reason:@"Telephony action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"telephony-action-registered-%@", listenerName]
                  reason:@"Telephony action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[telephonyActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"telephony-action-selector-%@", listenerName]
                  reason:@"Telephony action selector mapping did not match bundled metadata"];
    }

    [recorder expect:![expectedSelectors[@"libactivator.phone.answer-call"]
                         isEqualToString:expectedSelectors[@"libactivator.phone.disconnect-call"]]
            caseName:@"telephony-action-selectors-are-distinct"
              reason:@"Answer and disconnect call actions must not share selector metadata"];

    [recorder expect:![activator hasListenerWithName:@"libactivator.phone"]
            caseName:@"phone-group-name-not-registered"
              reason:@"Phone group name was registered as an action listener"];
    [recorder expect:![[NSSet setWithArray:[telephonyActionClass supportedListenerNames]]
                         containsObject:@"libactivator.phone.recents"]
            caseName:@"phone-url-action-not-owned-by-telephony-listener"
              reason:@"Phone tab URL action remained in LATTelephonyActionListener"];

    id<LAListener> telephonyAction = [[(Class)telephonyActionClass alloc] init];
    LAEvent *unsupportedEvent = [LAEvent eventWithName:@"libactivator.test.built-in.telephony"
                                                  mode:LAEventModeSpringBoard];
    [telephonyAction activator:activator
                  receiveEvent:unsupportedEvent
               forListenerName:@"libactivator.test.telephony.unsupported"];
    [recorder expect:!unsupportedEvent.handled
            caseName:@"telephony-action-unsupported-name-unhandled"
              reason:@"Unsupported telephony action listener name consumed the event"];
}

@end
