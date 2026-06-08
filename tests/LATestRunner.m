//
//  LATestRunner.m
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunner.h"

#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Activator/Activator.h>

#import "LAActivatorIPC.h"
#import "LATestRunnerRecorder.h"

@interface LATestRunner ()
- (BOOL)waitUntilTrue:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout;
@end

@implementation LATestRunner {
    CPDistributedMessagingCenter *_center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LAActivatorIPCServerName];
    }
    return self;
}

#pragma mark - Commands

- (int)runStableTests {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self sendCommand:LAActivatorIPCTestingCommandCleanup];
    printf("[tests] Running runner client facade test suites\n");
    fflush(stdout);
    NSDictionary *clientResult = [self runClientFacadeTests];
    [self printResult:clientResult];
    [self sendCommand:LAActivatorIPCTestingCommandCleanup];
    if ([self resultHasFailures:clientResult]) {
        return 1;
    }

    return [self runSpringBoardCommand:LAActivatorIPCTestingCommandRun suiteName:@"stable"];
}

- (int)runRuntimeInputTests {
    return [self runSpringBoardCommand:LAActivatorIPCTestingCommandRunRuntimeInput suiteName:@"runtime input"];
}

- (int)runDeviceRuntimeTests {
    return [self runSpringBoardCommand:LAActivatorIPCTestingCommandRunDeviceRuntime suiteName:@"device runtime"];
}

- (int)watchRuntimeState {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    printf("[runtime] time mode underneath display frontMost screenOn uiLocked lockVisible sbInterface inLockScreen homeSources springBoardSources lockSources\n");
    fflush(stdout);
    while (YES) {
        NSDictionary *reply = [self sendCommand:LAActivatorIPCTestingCommandRuntimeState];
        NSDictionary *state =
            [reply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAActivatorIPCKeyValue] : nil;
        if (![reply[LAActivatorIPCKeyOK] boolValue] || !state) {
            fprintf(stderr, "[runtime] unavailable\n");
            [NSThread sleepForTimeInterval:1.0];
            continue;
        }
        [self printRuntimeState:state];
        [NSThread sleepForTimeInterval:0.5];
    }
}

#pragma mark - Runner-Owned Tests

- (NSDictionary *)runClientFacadeTests {
    LATestRunnerRecorder *recorder = [[LATestRunnerRecorder alloc] init];
    [recorder beginSuite:@"ClientFacade"];

    LAActivator *activator = [LAActivator sharedInstance];
    NSString *nothingName = @"libactivator.system.nothing";
    NSString *eventName = LAEventNameVolumeDownPress;
    NSString *displayIdentifier = @"com.libactivator.tests.client";
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
    [self sendSelector:@selector(sendAbortEvent:toListenerWithName:) toActivator:activator nilEventWithObject:nothingName];
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
    BOOL receivedAssignmentNotification =
        [self waitUntilTrue:^BOOL {
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

    NSDictionary *probeReply = [self sendCommand:LAActivatorIPCTestingCommandPrepareUserInfoProbe];
    NSDictionary *probeInfo = [probeReply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class]
                                  ? probeReply[LAActivatorIPCKeyValue]
                                  : nil;
    NSString *probeEventName = [probeInfo[LAActivatorIPCKeyEventName] isKindOfClass:NSString.class]
                                   ? probeInfo[LAActivatorIPCKeyEventName]
                                   : @"";
    NSString *probeListenerName = [probeInfo[LAActivatorIPCKeyListenerName] isKindOfClass:NSString.class]
                                      ? probeInfo[LAActivatorIPCKeyListenerName]
                                      : @"";
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
    NSDictionary *probeResultReply = [self sendCommand:LAActivatorIPCTestingCommandUserInfoProbeResult];
    NSDictionary *probeResult = [probeResultReply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class]
                                    ? probeResultReply[LAActivatorIPCKeyValue]
                                    : nil;
    NSDictionary *receivedUserInfo = [probeResult[@"UserInfo"] isKindOfClass:NSDictionary.class]
                                         ? probeResult[@"UserInfo"]
                                         : nil;
    [recorder expect:userInfoEvent.handled && [probeResult[@"ReceiveCount"] integerValue] == 1
            caseName:@"dispatch-user-info-probe"
              reason:@"Client dispatch userInfo probe did not reach SpringBoard"];
    [recorder expect:[receivedUserInfo[@"safe"] isEqual:@"value"] && [receivedUserInfo[@"nested"][@"safe"] isEqual:@42] &&
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

#pragma mark - SpringBoard-Owned Tests

- (int)runSpringBoardCommand:(NSString *)command suiteName:(NSString *)suiteName {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self sendCommand:LAActivatorIPCTestingCommandCleanup];
    printf("[tests] Running SpringBoard %s test suites\n", [suiteName UTF8String]);
    fflush(stdout);
    NSDictionary *reply = [self sendCommand:command];
    if (![reply[LAActivatorIPCKeyOK] boolValue]) {
        fprintf(stderr, "[tests] Test command failed\n");
        [self sendCommand:LAActivatorIPCTestingCommandCleanup];
        return 3;
    }
    NSDictionary *result =
        [reply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAActivatorIPCKeyValue] : nil;
    if (!result) {
        fprintf(stderr, "[tests] Test command returned no result\n");
        [self sendCommand:LAActivatorIPCTestingCommandCleanup];
        return 3;
    }
    [self printResult:result];
    [self sendCommand:LAActivatorIPCTestingCommandCleanup];

    return [self resultHasFailures:result] ? 1 : 0;
}

#pragma mark - IPC

- (BOOL)waitForServer {
    for (NSInteger attempt = 0; attempt < 60; attempt++) {
        NSDictionary *reply = [self sendCommand:LAActivatorIPCTestingCommandPing];
        if ([reply[LAActivatorIPCKeyOK] boolValue]) {
            printf("[tests] SpringBoard test server is ready\n");
            fflush(stdout);
            return YES;
        }
        if (attempt == 0 || (attempt + 1) % 5 == 0) {
            printf("[tests] Still waiting for SpringBoard test server (%ld/60)\n", (long)(attempt + 1));
            fflush(stdout);
        }
        [NSThread sleepForTimeInterval:1.0];
    }
    return NO;
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

- (NSDictionary *)sendCommand:(NSString *)command {
    NSDictionary *reply = [_center sendMessageAndReceiveReplyName:LAActivatorIPCMessageTesting
                                                         userInfo:@{LAActivatorIPCKeyTestingCommand : command ?: @""}];
    return [reply isKindOfClass:NSDictionary.class] ? reply : @{};
}

#pragma mark - Result Output

- (void)printResult:(NSDictionary *)result {
    NSInteger suiteCount = [result[LAActivatorIPCKeyTestingSuites] count];
    NSInteger caseCount = [result[LAActivatorIPCKeyTestingCaseCount] integerValue];
    NSInteger passCount = [result[LAActivatorIPCKeyTestingPassCount] integerValue];
    NSInteger failureCount = [result[LAActivatorIPCKeyTestingFailureCount] integerValue];
    NSInteger skipCount = [result[LAActivatorIPCKeyTestingSkipCount] integerValue];

    printf("[tests] Suites: %ld, Cases: %ld, Passed: %ld, Failed: %ld, Skipped: %ld\n", (long)suiteCount,
           (long)caseCount, (long)passCount, (long)failureCount, (long)skipCount);
    fflush(stdout);

    NSArray *failures = [result[LAActivatorIPCKeyTestingFailures] isKindOfClass:NSArray.class]
                            ? result[LAActivatorIPCKeyTestingFailures]
                            : @[];
    for (NSString *failure in failures) {
        printf("[tests] FAIL: %s\n", [failure UTF8String]);
        fflush(stdout);
    }

    NSArray *skipped = [result[LAActivatorIPCKeyTestingSkipped] isKindOfClass:NSArray.class]
                           ? result[LAActivatorIPCKeyTestingSkipped]
                           : @[];
    for (NSString *skip in skipped) {
        printf("[tests] SKIP: %s\n", [skip UTF8String]);
        fflush(stdout);
    }
}

- (BOOL)resultHasFailures:(NSDictionary *)result {
    return [result[LAActivatorIPCKeyTestingFailureCount] integerValue] > 0;
}

#pragma mark - Runtime State Output

- (void)printRuntimeState:(NSDictionary *)state {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";

    NSArray *homeSourceValues = [state[@"HomeSources"] isKindOfClass:NSArray.class] ? state[@"HomeSources"] : @[];
    NSArray *springBoardSourceValues = [state[@"SpringBoardInterfaceSources"] isKindOfClass:NSArray.class]
                                           ? state[@"SpringBoardInterfaceSources"]
                                           : @[];
    NSArray *lockSourceValues = [state[@"LockSources"] isKindOfClass:NSArray.class] ? state[@"LockSources"] : @[];
    NSString *homeSources = [homeSourceValues componentsJoinedByString:@","];
    NSString *springBoardSources = [springBoardSourceValues componentsJoinedByString:@","];
    NSString *lockSources = [lockSourceValues componentsJoinedByString:@","];
    NSString *mode = [state[@"Mode"] isKindOfClass:NSString.class] ? state[@"Mode"] : @"";
    NSString *underneathMode = [state[@"UnderneathMode"] isKindOfClass:NSString.class] ? state[@"UnderneathMode"] : @"";
    NSString *displayIdentifier =
        [state[@"DisplayIdentifier"] isKindOfClass:NSString.class] ? state[@"DisplayIdentifier"] : @"";
    NSString *frontMost = [state[@"FrontMost"] isKindOfClass:NSString.class] ? state[@"FrontMost"] : @"";

    printf("[runtime] %s mode=%s underneath=%s display=%s frontMost=%s screenOn=%s uiLocked=%s lockVisible=%s sbInterface=%s inLockScreen=%s home=%s springBoard=%s lock=%s\n",
           [[formatter stringFromDate:NSDate.date] UTF8String],
           [mode UTF8String],
           [underneathMode UTF8String],
           [displayIdentifier UTF8String],
           [frontMost UTF8String],
           [state[@"ScreenOn"] boolValue] ? "YES" : "NO",
           [state[@"UILocked"] boolValue] ? "YES" : "NO",
           [state[@"LockScreenVisible"] boolValue] ? "YES" : "NO",
           [state[@"SpringBoardInterfaceVisible"] boolValue] ? "YES" : "NO",
           [state[@"InLockScreen"] boolValue] ? "YES" : "NO",
           [homeSources UTF8String],
           [springBoardSources UTF8String],
           [lockSources UTF8String]);
    fflush(stdout);
}

#pragma mark - Assertions

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
