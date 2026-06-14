//
//  LATEdgeGestureEventSource.h
//  libactivator
//
//  Created by OpenAI on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATEdgeGestureEventSource : NSObject

// Main-queue confined. The first implementation only classifies and logs edge slide gestures.
- (void)start;
- (void)noteSystemGestureWindow:(UIWindow *)window event:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
