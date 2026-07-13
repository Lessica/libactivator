//
//  LATestRunner.m
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunner.h"

#import "LAIPC.h"
#import "LATestClientFacadeSuite.h"
#import "LATestRunnerResultPrinter.h"
#import "LATestRuntimeStatePrinter.h"
#import "LATestSpringBoardClient.h"

@interface LATestRunner ()
@property(nonatomic, strong) LATestSpringBoardClient *client;
@property(nonatomic, strong) LATestRunnerResultPrinter *resultPrinter;
@property(nonatomic, strong) LATestRuntimeStatePrinter *runtimeStatePrinter;
@end

@implementation LATestRunner

- (instancetype)init {
    self = [super init];
    if (self) {
        _client = [[LATestSpringBoardClient alloc] init];
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

    [self.client sendCommand:LAIPCTestingCommandCleanup];
    printf("[tests] Running runner client facade test suites\n");
    fflush(stdout);
    NSDictionary *clientResult = [[[LATestClientFacadeSuite alloc] initWithClient:self.client] run];
    [self.resultPrinter printResult:clientResult];
    [self.client sendCommand:LAIPCTestingCommandCleanup];
    if ([self.resultPrinter resultHasFailures:clientResult]) {
        return 1;
    }

    return [self runSpringBoardCommand:LAIPCTestingCommandRun suiteName:@"stable"];
}

- (int)runRuntimeInputTests {
    return [self runSpringBoardCommand:LAIPCTestingCommandRunRuntimeInput suiteName:@"runtime input"];
}

- (int)runDeviceRuntimeTests {
    return [self runSpringBoardCommand:LAIPCTestingCommandRunDeviceRuntime suiteName:@"device runtime"];
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
        NSDictionary *reply = [self.client sendCommand:LAIPCTestingCommandRuntimeState];
        NSDictionary *state = [reply[LAIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAIPCKeyValue] : nil;
        if (![reply[LAIPCKeyOK] boolValue] || !state) {
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

    [self.client sendCommand:LAIPCTestingCommandCleanup];
    printf("[tests] Running SpringBoard %s test suites\n", [suiteName UTF8String]);
    fflush(stdout);
    NSDictionary *reply = [self.client sendCommand:command];
    if (![reply[LAIPCKeyOK] boolValue]) {
        fprintf(stderr, "[tests] Test command failed\n");
        [self.client sendCommand:LAIPCTestingCommandCleanup];
        return 3;
    }
    NSDictionary *result = [reply[LAIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LAIPCKeyValue] : nil;
    if (!result) {
        fprintf(stderr, "[tests] Test command returned no result\n");
        [self.client sendCommand:LAIPCTestingCommandCleanup];
        return 3;
    }
    [self.resultPrinter printResult:result];
    [self.client sendCommand:LAIPCTestingCommandCleanup];

    return [self.resultPrinter resultHasFailures:result] ? 1 : 0;
}

@end
