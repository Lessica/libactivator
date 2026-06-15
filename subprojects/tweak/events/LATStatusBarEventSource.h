//
//  LATStatusBarEventSource.h
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class LATEventSourceInterestGate;

@interface LATStatusBarEventSource : NSObject

@property(nonatomic, weak, nullable) LATEventSourceInterestGate *interestGate;

// Main-queue confined. This source observes SpringBoard-owned status bar views and submits
// Activator events without consuming the original system touch handling.

// Lifecycle
- (void)start;

// Touch ingestion
- (void)noteStatusBarView:(UIView *)view touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view
         touchesCancelled:(NSSet<UITouch *> *)touches
                withEvent:(nullable UIEvent *)event;

#if DEBUG
// Testing hooks
- (void)la_testingNoteTouchBeganInStatusBarView:(id)view
                                         bounds:(CGRect)bounds
                                       location:(CGPoint)location
                                       tapCount:(NSUInteger)tapCount;
- (void)la_testingNoteTouchMovedInStatusBarView:(id)view bounds:(CGRect)bounds location:(CGPoint)location;
- (void)la_testingNoteTouchEndedInStatusBarView:(id)view tapCount:(NSUInteger)tapCount;
- (void)la_testingNoteTouchCancelledInStatusBarView:(id)view;
- (void)la_testingNoteTouchCancelledInStatusBarView:(id)view
                                             bounds:(CGRect)bounds
                                           location:(CGPoint)location
                                           tapCount:(NSUInteger)tapCount;
- (BOOL)la_testingHasSessionForStatusBarView:(id)view;
#endif

@end

NS_ASSUME_NONNULL_END
