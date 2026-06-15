//
//  LATEdgeGestureEventSource.h
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LATFingerprintSensorEventSource;
@class LATEventSourceInterestGate;

NS_ASSUME_NONNULL_BEGIN

@interface LATEdgeGestureEventSource : NSObject

@property(nonatomic, weak, nullable) LATFingerprintSensorEventSource *fingerprintSensorEventSource;
@property(nonatomic, weak, nullable) LATEventSourceInterestGate *interestGate;

// Main-queue confined. This source observes system gesture window events and dispatches
// Activator edge slide events without consuming the original system touch handling.

// Lifecycle
- (void)start;

// Touch ingestion
- (void)noteSystemGestureWindow:(UIWindow *)window event:(nullable UIEvent *)event;

#if DEBUG
// Testing hooks
- (nullable NSString *)la_testingNoteTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                             bounds:(CGRect)bounds
                                          timestamp:(NSTimeInterval)timestamp;
#endif

@end

NS_ASSUME_NONNULL_END
