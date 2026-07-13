//
//  LATEventSourceIngress.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "IOKitSPI.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventSourceHIDIngress <NSObject>
- (void)noteHIDEvent:(IOHIDEventRef)event;
@end

@protocol LATEventSourceSystemGestureWindowIngress <NSObject>
- (void)noteSystemGestureWindow:(UIWindow *)window event:(nullable UIEvent *)event;
@end

@protocol LATEventSourceNetworkStateIngress <NSObject>
- (void)noteNetworkStateMayHaveChangedWithReason:(NSString *)reason;
@end

@protocol LATEventSourceStatusBarTouchIngress <NSObject>
- (void)noteStatusBarView:(UIView *)view touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)noteStatusBarView:(UIView *)view
         touchesCancelled:(NSSet<UITouch *> *)touches
                withEvent:(nullable UIEvent *)event;
@end

@protocol LATEventSourceMotionIngress <NSObject>
- (void)noteMotionEnded:(UIEventSubtype)motion;
@end

@protocol LATEventSourceIconScrollViewIngress <NSObject>
- (void)noteIconScrollViewDidInitialize:(UIScrollView *)scrollView;
@end

NS_ASSUME_NONNULL_END
