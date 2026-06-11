//
//  LATestRunnerResultPrinter.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunnerResultPrinter.h"

#import "LAIPC.h"

@implementation LATestRunnerResultPrinter

- (void)printResult:(NSDictionary *)result {
    NSInteger suiteCount = [result[LAIPCKeyTestingSuites] count];
    NSInteger caseCount = [result[LAIPCKeyTestingCaseCount] integerValue];
    NSInteger passCount = [result[LAIPCKeyTestingPassCount] integerValue];
    NSInteger failureCount = [result[LAIPCKeyTestingFailureCount] integerValue];
    NSInteger skipCount = [result[LAIPCKeyTestingSkipCount] integerValue];

    printf("[tests] Suites: %ld, Cases: %ld, Passed: %ld, Failed: %ld, Skipped: %ld\n", (long)suiteCount,
           (long)caseCount, (long)passCount, (long)failureCount, (long)skipCount);
    fflush(stdout);

    NSArray *failures =
        [result[LAIPCKeyTestingFailures] isKindOfClass:NSArray.class] ? result[LAIPCKeyTestingFailures] : @[];
    for (NSString *failure in failures) {
        printf("[tests] FAIL: %s\n", [failure UTF8String]);
        fflush(stdout);
    }

    NSArray *skipped =
        [result[LAIPCKeyTestingSkipped] isKindOfClass:NSArray.class] ? result[LAIPCKeyTestingSkipped] : @[];
    for (NSString *skip in skipped) {
        printf("[tests] SKIP: %s\n", [skip UTF8String]);
        fflush(stdout);
    }
}

- (BOOL)resultHasFailures:(NSDictionary *)result {
    return [result[LAIPCKeyTestingFailureCount] integerValue] > 0;
}

@end
