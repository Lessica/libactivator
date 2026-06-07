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
    NSString *eventName = @"libactivator.test.client-facade";
    NSString *displayIdentifier = @"com.libactivator.tests.client";
    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];

    [recorder expect:activator.version == LAActivatorVersion_2_0
            caseName:@"version"
              reason:@"Unexpected public API version"];
    [recorder expect:[activator hasListenerWithName:nothingName]
            caseName:@"remote-has-listener"
              reason:@"SpringBoard built-in listener was not visible from the client facade"];
    [recorder expect:[activator listenerForName:nothingName] != nil
            caseName:@"remote-listener-proxy"
              reason:@"Client facade did not return a remote listener proxy"];

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

    [activator assignEvent:event toListenerWithName:nothingName];
    [recorder expect:[[activator assignedListenerNamesForEvent:event] isEqualToArray:@[ nothingName ]]
            caseName:@"assignment-round-trip"
              reason:@"Client assignment did not round-trip through SpringBoard"];
    [recorder expect:[self events:[activator eventsAssignedToListenerWithName:nothingName]
               containEventName:eventName
                            mode:LAEventModeSpringBoard]
            caseName:@"reverse-assignment"
              reason:@"Client reverse assignment lookup did not include the assigned event"];

    [activator sendEventToListener:event];
    [recorder expect:event.handled
            caseName:@"dispatch-handled-reply"
              reason:@"Client dispatch did not receive the handled state from SpringBoard"];

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
