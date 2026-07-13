//
//  LATMultiTouchGestureRecognizer.h
//  libactivator
//
//  Created by Lessica on 7/1/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATMultiTouchGestureRecognizer : UIGestureRecognizer

@property(nonatomic, copy, readonly, nullable) NSString *recognizedEventName;
@property(nonatomic, assign, readonly) NSUInteger recognizedTouchCount;

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
