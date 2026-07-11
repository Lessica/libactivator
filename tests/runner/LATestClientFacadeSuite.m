//
//  LATestClientFacadeSuite.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestClientFacadeSuite.h"

#import "LAActivator+Private.h"
#import "LAIPC.h"
#import "LATestRunnerRecorder.h"
#import "LATestSpringBoardClient.h"

#import <Activator/Activator.h>

@interface LATestClientFacadeSuite ()
@property(nonatomic, strong) LATestSpringBoardClient *client;
@end

@implementation LATestClientFacadeSuite

- (instancetype)initWithClient:(LATestSpringBoardClient *)client {
    self = [super init];
    if (self) {
        _client = client;
    }
    return self;
}

- (NSDictionary *)run {
    LATestRunnerRecorder *recorder = [[LATestRunnerRecorder alloc] init];
    [recorder beginSuite:@"ClientFacade"];

    LAActivator *activator = [LAActivator sharedInstance];
    NSString *nothingName = @"libactivator.system.nothing";
    NSString *eventName = LAEventNameVolumeDownPress;
    NSString *displayIdentifier = @"libactivator.tests.client";
    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    LAEvent *allModesEvent = [LAEvent eventWithName:eventName];

    [recorder expect:activator.version == LAActivatorVersion_2_0
            caseName:@"version"
              reason:@"Unexpected public API version"];
    [recorder expect:[activator hasListenerWithName:nothingName]
            caseName:@"remote-has-listener"
              reason:@"SpringBoard built-in listener was not visible from the client facade"];
    [recorder expect:[activator listenerForName:nothingName] != nil
            caseName:@"remote-listener-proxy"
              reason:@"Client facade did not return a remote listener proxy"];
    id<LAListener> remoteListener = [activator listenerForName:nothingName];
    LAEvent *remoteProxyEvent = [LAEvent eventWithName:@"libactivator.test.client.remote-proxy"
                                                  mode:LAEventModeSpringBoard];
    [remoteListener activator:activator receiveEvent:remoteProxyEvent forListenerName:nothingName];
    [recorder expect:remoteProxyEvent.handled
            caseName:@"remote-listener-proxy-receive"
              reason:@"Remote listener proxy did not forward receiveEvent to SpringBoard"];

    NSDictionary *unknownTestingReply = [self.client sendCommand:@"unknown-command"];
    [recorder expect:![unknownTestingReply[LAIPCKeyOK] boolValue]
            caseName:@"unknown-testing-command-fallback"
              reason:@"Testing IPC did not fail safely for an unknown command"];

    NSDictionary *configurationProbeReply = [self.client sendCommand:LAIPCTestingCommandPrepareEventConfigurationProbe];
    NSDictionary *configurationProbeInfo = [configurationProbeReply[LAIPCKeyValue] isKindOfClass:NSDictionary.class]
                                               ? configurationProbeReply[LAIPCKeyValue]
                                               : nil;
    NSString *configurationEventName = [configurationProbeInfo[LAIPCKeyEventName] isKindOfClass:NSString.class]
                                           ? configurationProbeInfo[LAIPCKeyEventName]
                                           : @"";
    NSDictionary *configurationDescriptor =
        [activator la_eventConfigurationDescriptorForEventName:configurationEventName];
    [recorder expect:[configurationProbeReply[LAIPCKeyOK] boolValue] &&
                     [activator eventWithNameSupportsConfiguration:configurationEventName]
            caseName:@"event-configuration-support-round-trip"
              reason:@"Client facade did not expose SpringBoard event configuration support"];
    [recorder expect:[configurationDescriptor[LAIPCKeyEventConfigurationClassName]
                         isEqual:configurationProbeInfo[LAIPCKeyEventConfigurationClassName]] &&
                     [configurationDescriptor[LAIPCKeyEventConfigurationBundlePath]
                         isEqual:configurationProbeInfo[LAIPCKeyEventConfigurationBundlePath]]
            caseName:@"event-configuration-descriptor-round-trip"
              reason:@"Client facade did not preserve the SpringBoard configuration descriptor"];

    id initialEventConfiguration = [activator la_configurationForEventWithName:configurationEventName];
    [recorder expect:[initialEventConfiguration isEqual:configurationProbeInfo[LAIPCKeyEventConfiguration]]
            caseName:@"event-configuration-get-round-trip"
              reason:@"Client facade did not retrieve the SpringBoard event configuration"];

    NSDictionary *savedEventConfiguration = @{
        @"Enabled" : @NO,
        @"Threshold" : @5,
    };
    BOOL savedEventConfigurationAccepted = [activator la_saveConfiguration:savedEventConfiguration
                                                          forEventWithName:configurationEventName];
    id roundTrippedEventConfiguration = [activator la_configurationForEventWithName:configurationEventName];
    [recorder expect:savedEventConfigurationAccepted && [roundTrippedEventConfiguration isEqual:savedEventConfiguration]
            caseName:@"event-configuration-save-round-trip"
              reason:@"Client facade did not save and retrieve the SpringBoard event configuration"];

    NSDictionary *malformedEventConfiguration = @{
        @"Enabled" : @YES,
        @"Nested" : @{
            @"Invalid" : [[NSObject alloc] init],
        },
    };
    BOOL malformedEventConfigurationAccepted = [activator la_saveConfiguration:malformedEventConfiguration
                                                              forEventWithName:configurationEventName];
    id eventConfigurationAfterRejectedSave = [activator la_configurationForEventWithName:configurationEventName];
    [recorder expect:!malformedEventConfigurationAccepted &&
                     [eventConfigurationAfterRejectedSave isEqual:savedEventConfiguration]
            caseName:@"event-configuration-save-rejects-malformed-payload"
              reason:@"Client facade accepted or partially saved a malformed event configuration"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    id largeIcon = [activator iconForListenerName:nothingName];
#pragma clang diagnostic pop
    [recorder expect:largeIcon == nil
            caseName:@"large-icon-noop"
              reason:@"Deprecated large listener icon API returned an image"];
    [recorder expect:[activator assignmentWarningForEventWithName:LAEventNameVolumeMuteOn] == nil
            caseName:@"assignment-warning-fallback"
              reason:@"Client assignment warning fallback returned an unexpected value"];

    [activator setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:YES];
    [recorder expect:[activator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier]
            caseName:@"blacklist-set"
              reason:@"Client blacklist set did not round-trip through SpringBoard"];
    [activator setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:NO];
    [recorder expect:![activator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier]
            caseName:@"blacklist-clear"
              reason:@"Client blacklist clear did not round-trip through SpringBoard"];

    [activator setCurrentProfileName:@"ClientFacade"];
    [recorder expect:[activator.currentProfileName isEqualToString:@"ClientFacade"] &&
                     [activator.availableProfileNames containsObject:@"ClientFacade"]
            caseName:@"profile-round-trip"
              reason:@"Client profile change was not visible through the facade"];
    [activator setCurrentProfileName:@"Default"];

    [self sendSelector:@selector(sendEventToListener:) toActivator:activator nilEventWithObject:nil];
    [self sendSelector:@selector(sendEvent:toListenerWithName:) toActivator:activator nilEventWithObject:nothingName];
    [self sendSelector:@selector(sendAbortToListener:) toActivator:activator nilEventWithObject:nil];
    [self sendSelector:@selector(sendAbortEvent:toListenerWithName:)
               toActivator:activator
        nilEventWithObject:nothingName];
    [self sendSelector:@selector(sendDeactivateEventToListeners:) toActivator:activator nilEventWithObject:nil];
    [recorder expect:YES caseName:@"nil-event-dispatch-noop" reason:@"Nil event dispatch should not fail"];

    [activator assignEvent:event toListenerWithName:nothingName];
    [recorder expect:[[activator assignedListenerNamesForEvent:event] isEqualToArray:@[ nothingName ]]
            caseName:@"assignment-round-trip"
              reason:@"Client assignment did not round-trip through SpringBoard"];
    [recorder expect:[self events:[activator eventsAssignedToListenerWithName:nothingName]
                         containEventName:eventName
                                     mode:LAEventModeSpringBoard]
            caseName:@"reverse-assignment"
              reason:@"Client reverse assignment lookup did not include the assigned event"];
    [activator unassignEvent:allModesEvent];
    NSDate *notificationSettleDeadline = [NSDate dateWithTimeIntervalSinceNow:0.25];
    while ([notificationSettleDeadline timeIntervalSinceNow] > 0.0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:notificationSettleDeadline];
    }
    __block NSUInteger assignmentNotificationCount = 0;
    id assignmentObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAssignmentsChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        assignmentNotificationCount += 1;
                                                    }];
    [activator addListenerAssignment:nothingName toEvent:allModesEvent];
    BOOL receivedAssignmentNotification = [self
        waitUntilTrue:^BOOL {
            return assignmentNotificationCount > 0;
        }
              timeout:2.0];
    [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    [recorder expect:[[activator assignedListenerNamesForEvent:event] isEqualToArray:@[ nothingName ]]
            caseName:@"add-assignment-round-trip"
              reason:@"Client all-modes add assignment did not round-trip through SpringBoard"];
    [recorder expect:receivedAssignmentNotification
            caseName:@"assignment-system-notification"
              reason:@"Client did not receive bridged assignment notification"];
    [recorder expect:assignmentNotificationCount == 1
            caseName:@"all-modes-assignment-single-notification"
              reason:@"Client all-modes assignment emitted more than one bridged notification"];
    [NSNotificationCenter.defaultCenter removeObserver:assignmentObserver];
    [activator removeListenerAssignment:nothingName fromEvent:allModesEvent];
    [recorder expect:[activator assignedListenerNamesForEvent:event].count == 0
            caseName:@"remove-assignment-round-trip"
              reason:@"Client all-modes remove assignment did not round-trip through SpringBoard"];
    [activator addListenerAssignment:nothingName toEvent:event];

    [activator sendEventToListener:event];
    [recorder expect:event.handled
            caseName:@"dispatch-handled-reply"
              reason:@"Client dispatch did not receive the handled state from SpringBoard"];

    NSDictionary *probeReply = [self.client sendCommand:LAIPCTestingCommandPrepareUserInfoProbe];
    NSDictionary *probeInfo =
        [probeReply[LAIPCKeyValue] isKindOfClass:NSDictionary.class] ? probeReply[LAIPCKeyValue] : nil;
    NSString *probeEventName =
        [probeInfo[LAIPCKeyEventName] isKindOfClass:NSString.class] ? probeInfo[LAIPCKeyEventName] : @"";
    NSString *probeListenerName =
        [probeInfo[LAIPCKeyListenerName] isKindOfClass:NSString.class] ? probeInfo[LAIPCKeyListenerName] : @"";
    LAEvent *userInfoEvent = [LAEvent eventWithName:probeEventName mode:LAEventModeSpringBoard];
    userInfoEvent.userInfo = @{
        @"safe" : @"value",
        @"unsafe" : [[NSObject alloc] init],
        @"nested" : @{
            @"safe" : @42,
            @"unsafe" : [[NSObject alloc] init],
        },
        @"array" : @[ @"keep", [[NSObject alloc] init] ],
    };
    [activator sendEvent:userInfoEvent toListenerWithName:probeListenerName];
    NSDictionary *probeResultReply = [self.client sendCommand:LAIPCTestingCommandUserInfoProbeResult];
    NSDictionary *probeResult =
        [probeResultReply[LAIPCKeyValue] isKindOfClass:NSDictionary.class] ? probeResultReply[LAIPCKeyValue] : nil;
    NSDictionary *receivedUserInfo =
        [probeResult[@"UserInfo"] isKindOfClass:NSDictionary.class] ? probeResult[@"UserInfo"] : nil;
    [recorder expect:userInfoEvent.handled && [probeResult[@"ReceiveCount"] integerValue] == 1
            caseName:@"dispatch-user-info-probe"
              reason:@"Client dispatch userInfo probe did not reach SpringBoard"];
    [recorder
          expect:[receivedUserInfo[@"safe"] isEqual:@"value"] && [receivedUserInfo[@"nested"][@"safe"] isEqual:@42] &&
                 [receivedUserInfo[@"array"] isEqualToArray:@[ @"keep" ]] && receivedUserInfo[@"unsafe"] == nil &&
                 receivedUserInfo[@"nested"][@"unsafe"] == nil
        caseName:@"dispatch-user-info-plist-filter"
          reason:@"Client dispatch did not filter non-property-list userInfo values"];

    [activator unassignEvent:event];
    [recorder expect:[activator assignedListenerNamesForEvent:event].count == 0
            caseName:@"assignment-clear"
              reason:@"Client assignment clear did not round-trip through SpringBoard"];

    NSString *localizedTitle = [activator localizedTitleForListenerName:nothingName];
    [recorder expect:localizedTitle.length > 0
            caseName:@"localized-title"
              reason:@"Client localization lookup returned an empty title"];

    [activator setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:NO];
    [activator setCurrentProfileName:@"Default"];
    [activator unassignEvent:event];
    return [recorder resultDictionary];
}

- (BOOL)waitUntilTrue:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!predicate()) {
        if ([deadline timeIntervalSinceNow] <= 0.0) {
            return NO;
        }
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return YES;
}

- (void)sendSelector:(SEL)selector toActivator:(LAActivator *)activator nilEventWithObject:(id)object {
    NSMethodSignature *signature = [activator methodSignatureForSelector:selector];
    if (!signature) {
        return;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = activator;
    invocation.selector = selector;
    LAEvent *event = nil;
    [invocation setArgument:&event atIndex:2];
    if (signature.numberOfArguments > 3) {
        id objectArgument = object;
        [invocation setArgument:&objectArgument atIndex:3];
    }
    [invocation invoke];
}

- (BOOL)events:(NSArray *)events containEventName:(NSString *)eventName mode:(NSString *)mode {
    for (LAEvent *event in events) {
        if (![event isKindOfClass:LAEvent.class]) {
            continue;
        }
        BOOL modeMatches = (event.mode == mode) || [event.mode isEqualToString:mode];
        if ([event.name isEqualToString:eventName] && modeMatches) {
            return YES;
        }
    }
    return NO;
}

@end
