//
//  LAActivatorUnlockService.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAActivatorUnlockService : NSObject
- (BOOL)isUILocked;
- (BOOL)supportsUnlockingDeviceToSendEvents;
@end

NS_ASSUME_NONNULL_END
