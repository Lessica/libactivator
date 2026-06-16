//
//  LATSystemLockScreenController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemLockScreenController : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRuntimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource
    NS_DESIGNATED_INITIALIZER;

- (BOOL)showLockScreenForListenerName:(NSString *)listenerName;
- (BOOL)dismissLockScreenForListenerName:(NSString *)listenerName;
- (BOOL)toggleLockScreenForListenerName:(NSString *)listenerName;
- (BOOL)lockAndWipeCredentialsForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
