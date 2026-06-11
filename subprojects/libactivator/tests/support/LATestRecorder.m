//
//  LATestRecorder.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRecorder.h"

#import "LAActivatorIPC.h"

@implementation LATestRecorder

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _suites = [NSMutableArray array];
        _failures = [NSMutableArray array];
        _skipped = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Recording

- (void)beginSuite:(NSString *)suiteName {
    self.suiteName = suiteName ?: @"Unknown";
    [self.suites addObject:self.suiteName];
}

- (void)pass:(NSString *)caseName {
    self.caseCount += 1;
    self.passCount += 1;
}

- (void)fail:(NSString *)caseName reason:(NSString *)reason {
    self.caseCount += 1;
    self.failureCount += 1;
    [self.failures addObject:[NSString stringWithFormat:@"%@/%@: %@", self.suiteName ?: @"Unknown",
                                                        caseName ?: @"Unknown", reason ?: @"Failed"]];
}

- (void)skip:(NSString *)caseName reason:(NSString *)reason {
    self.caseCount += 1;
    self.skipCount += 1;
    [self.skipped addObject:[NSString stringWithFormat:@"%@/%@: %@", self.suiteName ?: @"Unknown",
                                                       caseName ?: @"Unknown", reason ?: @"Skipped"]];
}

- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason {
    if (condition) {
        [self pass:caseName];
    } else {
        [self fail:caseName reason:reason];
    }
}

#pragma mark - Result

- (NSDictionary<NSString *, id> *)resultDictionary {
    return @{
        LAActivatorIPCKeyTestingSuites : self.suites,
        LAActivatorIPCKeyTestingFailures : self.failures,
        LAActivatorIPCKeyTestingSkipped : self.skipped,
        LAActivatorIPCKeyTestingCaseCount : @(self.caseCount),
        LAActivatorIPCKeyTestingPassCount : @(self.passCount),
        LAActivatorIPCKeyTestingFailureCount : @(self.failureCount),
        LAActivatorIPCKeyTestingSkipCount : @(self.skipCount),
    };
}

@end

