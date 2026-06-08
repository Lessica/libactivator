//
//  LATestRunnerRecorder.m
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunnerRecorder.h"

#import "LAActivatorIPC.h"

@implementation LATestRunnerRecorder {
    NSMutableArray *_suites;
    NSMutableArray *_failures;
    NSInteger _caseCount;
    NSInteger _passCount;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _suites = [NSMutableArray array];
        _failures = [NSMutableArray array];
    }
    return self;
}

- (void)beginSuite:(NSString *)suiteName {
    if (suiteName.length > 0 && ![_suites containsObject:suiteName]) {
        [_suites addObject:suiteName];
    }
}

- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason {
    _caseCount += 1;
    if (condition) {
        _passCount += 1;
        return;
    }

    NSString *suiteName = [_suites lastObject] ?: @"Unknown";
    [_failures addObject:[NSString stringWithFormat:@"%@/%@: %@", suiteName, caseName ?: @"unknown",
                                                    reason ?: @"Expectation failed"]];
}

- (NSDictionary *)resultDictionary {
    return @{
        LAActivatorIPCKeyTestingSuites : [_suites copy],
        LAActivatorIPCKeyTestingFailures : [_failures copy],
        LAActivatorIPCKeyTestingSkipped : @[],
        LAActivatorIPCKeyTestingCaseCount : @(_caseCount),
        LAActivatorIPCKeyTestingPassCount : @(_passCount),
        LAActivatorIPCKeyTestingFailureCount : @(_failures.count),
        LAActivatorIPCKeyTestingSkipCount : @0,
    };
}

@end
