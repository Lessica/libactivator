//
//  LATEdgeGestureClassifier.h
//  libactivator
//
//  Created by OpenAI on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LATEdgeGestureTouchIdentifierKey;
extern NSString *const LATEdgeGestureTouchPhaseKey;
extern NSString *const LATEdgeGestureTouchLocationKey;

@interface LATEdgeGestureClassifier : NSObject

- (nullable NSString *)updateWithTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)touchSnapshots
                                         bounds:(CGRect)bounds
                                      timestamp:(NSTimeInterval)timestamp;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
