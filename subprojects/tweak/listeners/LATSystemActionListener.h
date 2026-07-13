//
//  LATSystemActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"
#import "LATNowPlayingProviding.h"
#import "LATSpringBoardInstanceProviding.h"

@class LATApplicationLauncher;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemActionListener : NSObject <LATBuiltInListenerRegistrant>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
              runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource
              nowPlayingProvider:(nullable id<LATNowPlayingProviding>)nowPlayingProvider
     springBoardInstanceProvider:(nullable id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
    NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
