//
//  LATHIDEventSender.h
//  ActivatorTweak
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATHIDEventSender : NSObject
- (BOOL)sendKeyboardUsagePage:(uint32_t)usagePage usage:(uint32_t)usage reason:(NSString *)reason;
@end

NS_ASSUME_NONNULL_END
