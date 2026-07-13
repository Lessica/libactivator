//
//  LATLockScreenCameraLauncher.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATSpringBoardInstanceProviding.h"

@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATLockScreenCameraLauncher : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRuntimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource
               springBoardInstanceProvider:(nullable id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
    NS_DESIGNATED_INITIALIZER;

- (BOOL)enqueueOpenLockScreenCamera;
- (BOOL)enqueueOpenLockScreenCameraWithCompletion:(nullable dispatch_block_t)completion;
- (BOOL)isLockScreenCameraVisible;

@end

NS_ASSUME_NONNULL_END
