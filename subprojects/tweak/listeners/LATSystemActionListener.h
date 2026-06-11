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
@class LATMediaEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher;
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                           mediaEventSource:(LATMediaEventSource *_Nullable)mediaEventSource;
@end

NS_ASSUME_NONNULL_END
