//
//  LATestBuiltInRingerActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInRingerActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInRingerActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInRingerActions"];

    Class<LATestRingerActionListenerTesting> ringerActionClass =
        (Class<LATestRingerActionListenerTesting>)NSClassFromString(@"LATRingerActionListener");
    [recorder expect:ringerActionClass != Nil
            caseName:@"ringer-action-class-available"
              reason:@"LATRingerActionListener class was not loaded in SpringBoard"];
    if (!ringerActionClass) {
        return;
    }

    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *expectedActions = @{
        @"libactivator.audio.reset-ringer-state" : @{
            @"selector" : @"resetRingerState",
            @"phase" : @"ringer-reset",
        },
        @"libactivator.audio.mute-ringer" : @{
            @"selector" : @"muteRinger",
            @"phase" : @"ringer-mute",
        },
        @"libactivator.audio.unmute-ringer" : @{
            @"selector" : @"unmuteRinger",
            @"phase" : @"ringer-unmute",
        },
        @"libactivator.audio.toggle-ringer-mute" : @{
            @"selector" : @"toggleRingerMute",
            @"phase" : @"ringer-toggle",
        },
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[ringerActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedActions.count
            caseName:@"ringer-action-allowlist-count"
              reason:@"Ringer action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedActions) {
        NSDictionary<NSString *, NSString *> *expectedAction = expectedActions[listenerName];
        [recorder expect:[supportedNames containsObject:listenerName]
                caseName:[NSString stringWithFormat:@"ringer-action-allowlist-%@", listenerName]
                  reason:@"Ringer action allowlist is missing an expected listener name"];
        [recorder expect:[[ringerActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedAction[@"selector"]]
                caseName:[NSString stringWithFormat:@"ringer-action-selector-%@", listenerName]
                  reason:@"Ringer action selector mapping did not match bundled metadata"];
        [recorder expect:[activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"ringer-action-registered-%@", listenerName]
                  reason:@"Ringer action was not registered"];
    }

    NSString *eventName = @"libactivator.test.built-in.ringer";
    NSString *toggleRingerName = @"libactivator.audio.toggle-ringer-mute";
    NSString *unknownName = @"libactivator.test.ringer.unknown";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    [activator registerEventDataSource:dataSource forEventName:eventName];

    for (NSString *listenerName in expectedActions) {
        NSDictionary<NSString *, NSString *> *expectedAction = expectedActions[listenerName];
        [ringerActionClass resetTestingState];
        [ringerActionClass setTestingActionHandler:^BOOL(NSString *name, NSString *phase) {
            return YES;
        }];
        LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
        [activator sendEvent:event toListenerWithName:listenerName];
        [recorder expect:event.handled &&
                         [[ringerActionClass testingLastActionListenerName] isEqualToString:listenerName] &&
                         [[ringerActionClass testingLastActionPhase] isEqualToString:expectedAction[@"phase"]]
                caseName:[NSString stringWithFormat:@"ringer-action-handles-%@", listenerName]
                  reason:@"Ringer action did not use the expected command path"];
    }

    [ringerActionClass resetTestingState];
    [ringerActionClass setTestingActionHandler:^BOOL(NSString *listenerName, NSString *phase) {
        return NO;
    }];
    LAEvent *failureEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:failureEvent toListenerWithName:toggleRingerName];
    [recorder expect:!failureEvent.handled
            caseName:@"ringer-action-failure-unhandled"
              reason:@"Ringer action marked the event handled when the controller failed"];

    [ringerActionClass resetTestingState];
    [ringerActionClass setTestingSelector:@"wrongSelector" forListenerName:toggleRingerName];
    [ringerActionClass setTestingActionHandler:^BOOL(NSString *listenerName, NSString *phase) {
        return YES;
    }];
    LAEvent *mismatchedSelectorEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:mismatchedSelectorEvent toListenerWithName:toggleRingerName];
    [recorder expect:!mismatchedSelectorEvent.handled && [ringerActionClass testingLastActionListenerName] == nil
            caseName:@"ringer-action-selector-mismatch-unhandled"
              reason:@"Ringer action handled an event with mismatched selector metadata"];

    id unknownRingerListener = [[(Class)ringerActionClass alloc] init];
    [activator registerListener:unknownRingerListener forName:unknownName];
    [ringerActionClass resetTestingState];
    [ringerActionClass setTestingActionHandler:^BOOL(NSString *listenerName, NSString *phase) {
        return YES;
    }];
    LAEvent *unknownEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:unknownEvent toListenerWithName:unknownName];
    [recorder expect:!unknownEvent.handled && [ringerActionClass testingLastActionListenerName] == nil
            caseName:@"ringer-action-unknown-name-unhandled"
              reason:@"Ringer action handled an unknown listener name"];

    [ringerActionClass resetTestingState];
}

@end

