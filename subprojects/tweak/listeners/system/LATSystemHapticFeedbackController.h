//
//  LATSystemHapticFeedbackController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LATSystemHapticFeedbackType) {
    LATSystemHapticFeedbackTypeFlick = 0,
    LATSystemHapticFeedbackTypeTap = 1,
    LATSystemHapticFeedbackTypeQuirk = 2,
};

@interface LATSystemHapticFeedbackController : NSObject
- (BOOL)performHapticFeedbackType:(LATSystemHapticFeedbackType)feedbackType listenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
