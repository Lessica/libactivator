//
//  main.m
//  libactivator-tests
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Foundation/Foundation.h>

#import "LAActivatorIPC.h"

@interface LATestRunner : NSObject
- (int)run;
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

- (int)run {
    printf("[tests] Waiting for SpringBoard test server\n");
    fflush(stdout);
    if (![self waitForServer]) {
        fprintf(stderr, "[tests] SpringBoard test server is not available\n");
        return 2;
    }

    [self sendCommand:LAActivatorIPCTestingCommandCleanup];
    printf("[tests] Running SpringBoard test suites\n");
    fflush(stdout);
    NSDictionary *reply = [self sendCommand:LAActivatorIPCTestingCommandRun];
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

    NSInteger failures = [result[LAActivatorIPCKeyTestingFailureCount] integerValue];
    return failures == 0 ? 0 : 1;
}

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

@end

int main(int argc, char **argv) {
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);
    @autoreleasepool {
        return [[[LATestRunner alloc] init] run];
    }
}
