//
//  LATLockStateEventSource.h
//  ActivatorTweak
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATLockStateEventSource : NSObject <LATEventSource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                       lockStateUpdater:(id<LATRuntimeLockStateUpdating>)lockStateUpdater
                 fingerprintCoordinator:(nullable id<LATFingerprintGestureCoordinating>)fingerprintCoordinator
    NS_DESIGNATED_INITIALIZER;

// Main-queue confined. This source reads SpringBoard lock state and submits events to the
// SpringBoard dispatch engine, so callers must start it from the SpringBoard main queue.
- (void)start;

@end

NS_ASSUME_NONNULL_END
