//
//  LATHardwareActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

@class LATMediaEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATHardwareActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
- (instancetype)initWithMediaEventSource:(nullable LATMediaEventSource *)mediaEventSource;
@end

NS_ASSUME_NONNULL_END
