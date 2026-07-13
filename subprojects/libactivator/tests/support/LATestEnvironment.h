//
//  LATestEnvironment.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LAActivator;
@class LARuntimeContext;

NS_ASSUME_NONNULL_BEGIN

@interface LATestEnvironment : NSObject

+ (LARuntimeContext *)runtimeContextForActivator:(LAActivator *)activator;

#pragma mark - Cleanup

+ (NSString *)testCachePathWithFileName:(NSString *)fileName;
+ (void)cleanActivator:(LAActivator *)activator;
+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator;
+ (void)removeTestPlist;

#pragma mark - Synchronization Helpers

+ (NSString *)runtimeDebugReasonWithPrefix:(nullable NSString *)prefix activator:(LAActivator *)activator;
+ (void)performOnMainThreadSynchronously:(nullable dispatch_block_t)block;
+ (BOOL)waitUntilTrue:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout;
+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval;
+ (void)waitForMainQueue;

@end

NS_ASSUME_NONNULL_END
