//
//  LATestRecorder.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestRecorder : NSObject

#pragma mark - Counters

@property(nonatomic, assign) NSInteger caseCount;
@property(nonatomic, assign) NSInteger passCount;
@property(nonatomic, assign) NSInteger failureCount;
@property(nonatomic, assign) NSInteger skipCount;

#pragma mark - Records

@property(nonatomic, copy, nullable) NSString *suiteName;
@property(nonatomic, strong) NSMutableArray<NSString *> *suites;
@property(nonatomic, strong) NSMutableArray<NSString *> *failures;
@property(nonatomic, strong) NSMutableArray<NSString *> *skipped;

#pragma mark - Recording

- (void)beginSuite:(NSString *)suiteName;
- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason;
- (void)skip:(NSString *)caseName reason:(NSString *)reason;

#pragma mark - Result

- (NSDictionary<NSString *, id> *)resultDictionary;
@end

NS_ASSUME_NONNULL_END

