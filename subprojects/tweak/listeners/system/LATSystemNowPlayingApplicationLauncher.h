//
//  LATSystemNowPlayingApplicationLauncher.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATEventSourceDependencies.h"

@class LATApplicationLauncher;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemNowPlayingApplicationLauncher : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         nowPlayingProvider:(nullable id<LATNowPlayingProviding>)nowPlayingProvider
    NS_DESIGNATED_INITIALIZER;

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
