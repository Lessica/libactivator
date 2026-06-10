//
//  LATestRunner.m
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunner.h"

#import "LAActivatorIPC.h"
#import "LATestClientFacadeSuite.h"
#import "LATestRunnerResultPrinter.h"
#import "LATestRuntimeStatePrinter.h"
#import "LATestSpringBoardTestClient.h"

@interface LATestRunner ()
@property(nonatomic, strong) LATestSpringBoardTestClient *client;
@property(nonatomic, strong) LATestRunnerResultPrinter *resultPrinter;
@property(nonatomic, strong) LATestRuntimeStatePrinter *runtimeStatePrinter;
@end

@implementation LATestRunner

- (instancetype)init {
    self = [super init];
    if (self) {
        _client = [[LATestSpringBoardTestClient alloc] init];
        _resultPrinter = [[LATestRunnerResultPrinter alloc] init];
        _runtimeStatePrinter = [[LATestRuntimeStatePrinter alloc] init];
    }
    return self;
}

#pragma mark - Commands

- (int)runStableTests {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self.client waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];
    printf("[tests] Running runner client facade test suites\n");
    fflush(stdout);
    NSDictionary *clientResult = [[[LATestClientFacadeSuite alloc] initWithClient:self.client] run];
    [self.resultPrinter printResult:clientResult];
    [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];
    if ([self.resultPrinter resultHasFailures:clientResult]) {
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
    if (![self.client waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self.runtimeStatePrinter printHeader];
    while (YES) {
        NSDictionary *reply = [self.client sendCommand:LAActivatorIPCTestingCommandRuntimeState];
        NSDictionary *state =
            [reply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAActivatorIPCKeyValue] : nil;
        if (![reply[LAActivatorIPCKeyOK] boolValue] || !state) {
            fprintf(stderr, "[runtime] unavailable\n");
            [NSThread sleepForTimeInterval:1.0];
            continue;
        }
        [self.runtimeStatePrinter printRuntimeState:state];
        [NSThread sleepForTimeInterval:0.5];
    }
}

#pragma mark - SpringBoard-Owned Tests

- (int)runSpringBoardCommand:(NSString *)command suiteName:(NSString *)suiteName {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self.client waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];
    printf("[tests] Running SpringBoard %s test suites\n", [suiteName UTF8String]);
    fflush(stdout);
    NSDictionary *reply = [self.client sendCommand:command];
    if (![reply[LAActivatorIPCKeyOK] boolValue]) {
        fprintf(stderr, "[tests] Test command failed\n");
        [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];
        return 3;
    }
    NSDictionary *result =
        [reply[LAActivatorIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAActivatorIPCKeyValue] : nil;
    if (!result) {
        fprintf(stderr, "[tests] Test command returned no result\n");
        [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];
        return 3;
    }
    [self.resultPrinter printResult:result];
    [self.client sendCommand:LAActivatorIPCTestingCommandCleanup];

    return [self.resultPrinter resultHasFailures:result] ? 1 : 0;
}

@end
