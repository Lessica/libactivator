//
//  LATestRunnerRecorder.h
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestRunnerRecorder : NSObject
- (void)beginSuite:(NSString *)suiteName;
- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason;
- (NSDictionary *)resultDictionary;
@end

NS_ASSUME_NONNULL_END
