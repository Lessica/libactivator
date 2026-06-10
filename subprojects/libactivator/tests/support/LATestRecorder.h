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
@property(nonatomic, assign) NSInteger caseCount;
@property(nonatomic, assign) NSInteger passCount;
@property(nonatomic, assign) NSInteger failureCount;
@property(nonatomic, assign) NSInteger skipCount;
@property(nonatomic, copy) NSString *suiteName;
@property(nonatomic, strong) NSMutableArray *suites;
@property(nonatomic, strong) NSMutableArray *failures;
@property(nonatomic, strong) NSMutableArray *skipped;
- (void)beginSuite:(NSString *)suiteName;
- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason;
- (void)skip:(NSString *)caseName reason:(NSString *)reason;
- (NSDictionary *)resultDictionary;
@end

NS_ASSUME_NONNULL_END

