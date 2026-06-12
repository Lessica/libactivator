//
//  LATLockScreenCameraLauncher.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATBuiltInRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATLockScreenCameraLauncher : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRegistry:(nullable LATBuiltInRegistry *)registry NS_DESIGNATED_INITIALIZER;

- (BOOL)enqueueOpenLockScreenCamera;

@end

NS_ASSUME_NONNULL_END
