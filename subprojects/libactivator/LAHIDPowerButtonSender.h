//
//  LAHIDPowerButtonSender.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAHIDPowerButtonSender : NSObject
- (BOOL)sendPowerButtonPressForReason:(NSString *)reason;
@end

NS_ASSUME_NONNULL_END
