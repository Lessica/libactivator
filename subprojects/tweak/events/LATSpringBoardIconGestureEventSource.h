//
//  LATSpringBoardIconGestureEventSource.h
//  libactivator
//
//  Created by Lessica on 7/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LATEventSource.h"

@class LATEventSourceRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATSpringBoardIconGestureEventSource : NSObject <LATEventSource>

@property(nonatomic, weak, nullable) LATEventSourceRegistry *eventSourceRegistry;

// Main-queue confined. This source reuses SBIconScrollView's existing pinch
// recognizer and dispatches SpringBoard icon pinch/spread events without adding
// a competing recognizer, consuming the original SpringBoard gesture handling,
// or scanning the SpringBoard view tree.

// Lifecycle
- (void)start;

// Gesture recognizer attachment
- (void)noteIconScrollViewDidInitialize:(UIScrollView *)scrollView;

#if DEBUG
// Testing hooks
- (nullable NSString *)la_testingHandlePinchScale:(CGFloat)scale
                                            state:(UIGestureRecognizerState)state
                                           bounds:(CGRect)bounds;
- (BOOL)la_testingHasRecognitionState;
- (NSUInteger)la_testingKnownIconScrollViewCount;
- (BOOL)la_testingIsInstalledInIconScrollView:(UIScrollView *)scrollView;
#endif

@end

NS_ASSUME_NONNULL_END
