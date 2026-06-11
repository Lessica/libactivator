//
//  LATHardwareHIDEventSender.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATHardwareActionCommand;

NS_ASSUME_NONNULL_BEGIN

@interface LATHardwareHIDEventSender : NSObject
- (BOOL)sendCommand:(LATHardwareActionCommand *)command listenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
