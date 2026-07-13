//
//  LATestBuiltInComposeActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInComposeActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInComposeActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInComposeActions"];

    Class<LATestComposeActionListener> composeActionClass =
        (Class<LATestComposeActionListener>)NSClassFromString(@"LATComposeActionListener");
    [recorder expect:composeActionClass != Nil
            caseName:@"compose-action-class-available"
              reason:@"LATComposeActionListener class was not loaded in SpringBoard"];
    if (!composeActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.mail.compose-message" : @"composeMail",
        @"libactivator.sms.compose-message" : @"composeText",
        @"libactivator.notes.compose-note" : @"composeNote",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[composeActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"compose-action-allowlist-count"
              reason:@"Compose action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"compose-action-registered-%@", listenerName]
                  reason:@"Compose action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[composeActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"compose-action-selector-%@", listenerName]
                  reason:@"Compose action selector mapping did not match bundled metadata"];
    }

    id<LATestComposeActionListener> composeAction =
        (id<LATestComposeActionListener>)[activator listenerForName:@"libactivator.mail.compose-message"];
    [recorder expect:[composeAction isKindOfClass:(Class)composeActionClass]
            caseName:@"compose-action-production-instance-available"
              reason:@"The registered compose action listener does not use LATComposeActionListener"];
    for (NSString *listenerName in expectedSelectors) {
        [recorder expect:[composeAction shouldHandleListenerName:listenerName activator:activator]
                caseName:[NSString stringWithFormat:@"compose-action-valid-metadata-handled-%@", listenerName]
                  reason:@"Compose action did not consume a listener name with matching selector metadata"];
    }

    [recorder expect:![composeAction shouldHandleListenerName:@"libactivator.mail.compose-message" activator:nil]
            caseName:@"compose-action-missing-metadata-unhandled"
              reason:@"Compose action consumed a listener name without matching selector metadata"];

    LAEvent *unsupportedEvent = [LAEvent eventWithName:@"libactivator.test.built-in.compose"
                                                  mode:LAEventModeSpringBoard];
    [composeAction activator:activator
                receiveEvent:unsupportedEvent
             forListenerName:@"libactivator.test.compose.unsupported"];
    [recorder expect:!unsupportedEvent.handled
            caseName:@"compose-action-unsupported-name-unhandled"
              reason:@"Unsupported compose action listener name consumed the event"];
}

@end
