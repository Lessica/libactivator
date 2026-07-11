//
//  LATLockStateEventSource.h
//  ActivatorTweak
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATEventSource.h"

@class LATRuntimeStateSource;
@class LATFingerprintSensorEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATLockStateEventSource : NSObject <LATEventSource>

@property(nonatomic, weak, nullable) LATFingerprintSensorEventSource *fingerprintSensorEventSource;

- (instancetype)initWithRuntimeStateSource:(LATRuntimeStateSource *)runtimeStateSource;

// Main-queue confined. This source reads SpringBoard lock state and submits events to the
// SpringBoard dispatch engine, so callers must start it from the SpringBoard main queue.
- (void)start;

@end

NS_ASSUME_NONNULL_END
