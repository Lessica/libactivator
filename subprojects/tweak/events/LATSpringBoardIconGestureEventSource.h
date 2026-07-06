//
//  LATSpringBoardIconGestureEventSource.h
//  libactivator
//
//  Created by Lessica on 7/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LATEventSourceInterestGate;

NS_ASSUME_NONNULL_BEGIN

@interface LATSpringBoardIconGestureEventSource : NSObject

@property(nonatomic, weak, nullable) LATEventSourceInterestGate *interestGate;

// Main-queue confined. This source reuses SBIconScrollView's existing pinch
// recognizer and dispatches SpringBoard icon pinch/spread events without adding
// a competing recognizer or consuming the original SpringBoard gesture handling.

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
#endif

@end

NS_ASSUME_NONNULL_END
