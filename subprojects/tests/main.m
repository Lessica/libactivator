//
//  main.m
//  libactivator-tests
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <AppSupport/CPDistributedMessagingCenter.h>
#import <Foundation/Foundation.h>

static NSString *const LATestIPCServerName = @"libactivator.springboard";
static NSString *const LATestIPCMessageTesting = @"libactivator.testing";
static NSString *const LATestIPCKeyOK = @"OK";
static NSString *const LATestIPCKeyValue = @"Value";
static NSString *const LATestIPCKeyTestingCommand = @"TestingCommand";
static NSString *const LATestIPCKeyTestingSuites = @"TestingSuites";
static NSString *const LATestIPCKeyTestingFailures = @"TestingFailures";
static NSString *const LATestIPCKeyTestingSkipped = @"TestingSkipped";
static NSString *const LATestIPCKeyTestingCaseCount = @"TestingCaseCount";
static NSString *const LATestIPCKeyTestingPassCount = @"TestingPassCount";
static NSString *const LATestIPCKeyTestingFailureCount = @"TestingFailureCount";
static NSString *const LATestIPCKeyTestingSkipCount = @"TestingSkipCount";

@interface LATestRunner : NSObject
- (int)run;
@end

@implementation LATestRunner {
    CPDistributedMessagingCenter *_center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LATestIPCServerName];
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

    [self sendCommand:@"cleanup"];
    printf("[tests] Running SpringBoard test suites\n");
    fflush(stdout);
    NSDictionary *reply = [self sendCommand:@"run"];
    if (![reply[LATestIPCKeyOK] boolValue]) {
        fprintf(stderr, "[tests] Test command failed\n");
        [self sendCommand:@"cleanup"];
        return 3;
    }
    NSDictionary *result = [reply[LATestIPCKeyValue] isKindOfClass:NSDictionary.class] ? reply[LATestIPCKeyValue] : nil;
    if (!result) {
        fprintf(stderr, "[tests] Test command returned no result\n");
        [self sendCommand:@"cleanup"];
        return 3;
    }
    [self printResult:result];
    [self sendCommand:@"cleanup"];

    NSInteger failures = [result[LATestIPCKeyTestingFailureCount] integerValue];
    return failures == 0 ? 0 : 1;
}

- (BOOL)waitForServer {
    for (NSInteger attempt = 0; attempt < 60; attempt++) {
        NSDictionary *reply = [self sendCommand:@"ping"];
        if ([reply[LATestIPCKeyOK] boolValue]) {
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
    NSDictionary *reply = [_center sendMessageAndReceiveReplyName:LATestIPCMessageTesting
                                                         userInfo:@{LATestIPCKeyTestingCommand : command ?: @""}];
    return [reply isKindOfClass:NSDictionary.class] ? reply : @{};
}

- (void)printResult:(NSDictionary *)result {
    NSInteger suiteCount = [result[LATestIPCKeyTestingSuites] count];
    NSInteger caseCount = [result[LATestIPCKeyTestingCaseCount] integerValue];
    NSInteger passCount = [result[LATestIPCKeyTestingPassCount] integerValue];
    NSInteger failureCount = [result[LATestIPCKeyTestingFailureCount] integerValue];
    NSInteger skipCount = [result[LATestIPCKeyTestingSkipCount] integerValue];

    printf("[tests] Suites: %ld, Cases: %ld, Passed: %ld, Failed: %ld, Skipped: %ld\n", (long)suiteCount,
           (long)caseCount, (long)passCount, (long)failureCount, (long)skipCount);
    fflush(stdout);

    NSArray *failures = [result[LATestIPCKeyTestingFailures] isKindOfClass:NSArray.class]
                            ? result[LATestIPCKeyTestingFailures]
                            : @[];
    for (NSString *failure in failures) {
        printf("[tests] FAIL: %s\n", [failure UTF8String]);
        fflush(stdout);
    }

    NSArray *skipped = [result[LATestIPCKeyTestingSkipped] isKindOfClass:NSArray.class]
                           ? result[LATestIPCKeyTestingSkipped]
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
