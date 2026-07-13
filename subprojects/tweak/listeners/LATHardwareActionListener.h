//
//  LATHardwareActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"
#import "LATEventSourceDependencies.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATHardwareActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
- (instancetype)initWithNowPlayingProvider:(nullable id<LATNowPlayingProviding>)nowPlayingProvider;
@end

NS_ASSUME_NONNULL_END
