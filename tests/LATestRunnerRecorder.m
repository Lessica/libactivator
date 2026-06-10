//
//  LATestRunnerRecorder.m
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRunnerRecorder.h"

#import "LAActivatorIPC.h"

@interface LATestRunnerRecorder ()
@property(nonatomic, strong) NSMutableArray<NSString *> *suites;
@property(nonatomic, strong) NSMutableArray<NSString *> *failures;
@property(nonatomic, assign) NSInteger caseCount;
@property(nonatomic, assign) NSInteger passCount;
@end

@implementation LATestRunnerRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _suites = [NSMutableArray array];
        _failures = [NSMutableArray array];
    }
    return self;
}

- (void)beginSuite:(NSString *)suiteName {
    if (suiteName.length > 0 && ![self.suites containsObject:suiteName]) {
        [self.suites addObject:suiteName];
    }
}

- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason {
    self.caseCount += 1;
    if (condition) {
        self.passCount += 1;
        return;
    }

    NSString *suiteName = [self.suites lastObject] ?: @"Unknown";
    [self.failures addObject:[NSString stringWithFormat:@"%@/%@: %@", suiteName, caseName ?: @"unknown",
                                                        reason ?: @"Expectation failed"]];
}

- (NSDictionary *)resultDictionary {
    return @{
        LAActivatorIPCKeyTestingSuites : [self.suites copy],
        LAActivatorIPCKeyTestingFailures : [self.failures copy],
        LAActivatorIPCKeyTestingSkipped : @[],
        LAActivatorIPCKeyTestingCaseCount : @(self.caseCount),
        LAActivatorIPCKeyTestingPassCount : @(self.passCount),
        LAActivatorIPCKeyTestingFailureCount : @(self.failures.count),
        LAActivatorIPCKeyTestingSkipCount : @0,
    };
}

@end
