//
//  LATestRunnerResultPrinter.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunnerResultPrinter.h"

#import "LAActivatorIPC.h"

@implementation LATestRunnerResultPrinter

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

@end
