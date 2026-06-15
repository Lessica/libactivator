//
//  LATSystemLockScreenController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemLockScreenController.h"

#import "LATRuntimeStateSource.h"

#import <HBLog.h>

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)remoteLock:(BOOL)lock;
- (BOOL)isUILocked;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode
                   finishUIUnlock:(BOOL)finishUIUnlock
                       completion:(nullable id)completion;
@end

@interface LATSystemLockScreenController ()
@property(nonatomic, weak, nullable) LATRuntimeStateSource *runtimeStateSource;
@end

@implementation LATSystemLockScreenController

- (instancetype)initWithRuntimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource {
    self = [super init];
    if (self) {
        _runtimeStateSource = runtimeStateSource;
    }
    return self;
}

- (BOOL)showLockScreenForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
        if (!manager) {
            return;
        }
        if (![manager respondsToSelector:@selector(remoteLock:)]) {
            HBLogError(@"SBLockScreenManager does not support remoteLock: for system action %@", listenerName ?: @"");
            return;
        }
        [manager remoteLock:YES];
    }];
}

- (BOOL)dismissLockScreenForListenerName:(NSString *)listenerName {
    dispatch_block_t unlockBlock = ^{
        SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
        if (!manager) {
            return;
        }
        if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
            [manager attemptUnlockWithPasscode:@"" finishUIUnlock:YES completion:nil];
        } else if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
            [manager attemptUnlockWithPasscode:@""];
        } else {
            HBLogError(@"SBLockScreenManager does not support passcode unlock for system action %@",
                       listenerName ?: @"");
        }
    };

    LATRuntimeStateSource *runtimeStateSource = self.runtimeStateSource;
    if (!runtimeStateSource) {
        HBLogWarn(@"Runtime state source is unavailable for lock screen dismiss action %@", listenerName ?: @"");
        return [self performOnMainQueueForListenerName:listenerName block:unlockBlock];
    }

    if ([runtimeStateSource screenIsOn]) {
        return [self performOnMainQueueForListenerName:listenerName block:unlockBlock];
    }

    if (![runtimeStateSource wakeScreenForReason:(listenerName ?: @"libactivator.lockscreen.dismiss")
                                      completion:unlockBlock]) {
        HBLogWarn(@"Screen wake was not started for lock screen dismiss action %@", listenerName ?: @"");
        return [self performOnMainQueueForListenerName:listenerName block:unlockBlock];
    }
    return YES;
}

- (BOOL)toggleLockScreenForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
        if (!manager) {
            return;
        }
        if (![manager respondsToSelector:@selector(isUILocked)]) {
            HBLogError(@"SBLockScreenManager does not support isUILocked for system action %@", listenerName ?: @"");
            return;
        }
        if ([manager isUILocked]) {
            [self dismissLockScreenForListenerName:listenerName];
        } else {
            [self showLockScreenForListenerName:listenerName];
        }
    }];
}

- (nullable SBLockScreenManager *)lockScreenManagerForListenerName:(NSString *)listenerName {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        HBLogError(@"SBLockScreenManager is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(id)managerClass sharedInstance];
}

- (BOOL)performOnMainQueueForListenerName:(NSString *)listenerName block:(dispatch_block_t)block {
    if (!block) {
        return NO;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    return YES;
}

@end
