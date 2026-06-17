//
//  LATForceTouchEventSource.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LATEventSourceInterestGate;

NS_ASSUME_NONNULL_BEGIN

@interface LATForceTouchEventSource : NSObject

@property(nonatomic, weak, nullable) LATEventSourceInterestGate *interestGate;

// Main-queue confined. This source observes system gesture window events and dispatches
// Activator force-touch events without consuming the original system touch handling.

// Lifecycle
- (void)start;

// Touch ingestion
- (void)noteSystemGestureWindow:(UIWindow *)window event:(nullable UIEvent *)event;

#if DEBUG
// Testing hooks
- (nullable NSString *)la_testingNoteTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                             bounds:(CGRect)bounds
                                          timestamp:(NSTimeInterval)timestamp;
- (nullable NSString *)la_testingEventNameForLocation:(CGPoint)location bounds:(CGRect)bounds;
- (BOOL)la_testingHasRecognitionState;
#endif

@end

NS_ASSUME_NONNULL_END
