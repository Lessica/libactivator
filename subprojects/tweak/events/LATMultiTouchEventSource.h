//
//  LATMultiTouchEventSource.h
//  libactivator
//
//  Created by Lessica on 7/1/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LATEventSource.h"

@class LATEventSourceRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATMultiTouchEventSource : NSObject <LATEventSource>

@property(nonatomic, weak, nullable) LATEventSourceRegistry *eventSourceRegistry;

// Main-queue confined. This source observes system gesture window events and dispatches
// Activator multi-touch events without consuming the original system touch handling.

// Lifecycle
- (void)start;

// Touch ingestion
- (void)noteSystemGestureWindow:(UIWindow *)window event:(nullable UIEvent *)event;

#if DEBUG
// Testing hooks
- (nullable NSString *)la_testingUpdateWithTouchLocations:(NSArray<NSValue *> *)touchLocations
                                                    phase:(UITouchPhase)phase
                                                   bounds:(CGRect)bounds
                                                timestamp:(NSTimeInterval)timestamp;
- (BOOL)la_testingHasRecognitionState;
#endif

@end

NS_ASSUME_NONNULL_END
