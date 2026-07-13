//
//  LAActivatorTestRegistry.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#if LIBACTIVATOR_TEST_SUPPORT

#import <Foundation/Foundation.h>
@class LAActivator;
@class LATestRecorder;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LAActivatorTestGroupCleanupBlock)(LAActivator *activator);
typedef void (^LAActivatorTestGroupRunBlock)(LATestRecorder *recorder, LAActivator *activator);

@interface LAActivatorTestRegistry : NSObject

+ (BOOL)registerGroupWithIdentifier:(NSString *)identifier
                       cleanupBlock:(LAActivatorTestGroupCleanupBlock)cleanupBlock
                   stableTestsBlock:(nullable LAActivatorTestGroupRunBlock)stableTestsBlock
            deviceRuntimeTestsBlock:(nullable LAActivatorTestGroupRunBlock)deviceRuntimeTestsBlock;
+ (BOOL)hasRegisteredGroups;
+ (void)cleanupRegisteredGroupsWithActivator:(LAActivator *)activator;
+ (void)runRegisteredStableTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runRegisteredDeviceRuntimeTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END

#endif
