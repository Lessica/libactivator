//
//  LATSystemActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

@class LATApplicationLauncher;
@class LATBuiltInRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
                        registry:(nullable LATBuiltInRegistry *)registry NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
