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
- (void)lockUIFromSource:(NSInteger)source
             withOptions:(NSDictionary<NSString *, id> *)options
              completion:(nullable id)completion;
- (BOOL)isUILocked;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode
                   finishUIUnlock:(BOOL)finishUIUnlock
                       completion:(nullable id)completion;
@end

static NSString *const LATLockOptionsUseScreenOffModeKey = @"SBUILockOptionsUseScreenOffModeKey";
static NSString *const LATLockOptionsForceBioLockoutKey = @"SBUILockOptionsForceBioLockoutKey";
static NSString *const LATLockOptionsForceLockKey = @"SBUILockOptionsForceLockKey";

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
    SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
    if (!manager) {
        return NO;
    }
    if (![manager respondsToSelector:@selector(remoteLock:)]) {
        HBLogError(@"SBLockScreenManager does not support remoteLock: for system action %@", listenerName ?: @"");
        return NO;
    }
    [manager remoteLock:YES];
    return YES;
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
        unlockBlock();
        return YES;
    }

    if ([runtimeStateSource screenIsOn]) {
        unlockBlock();
        return YES;
    }

    if (![runtimeStateSource wakeScreenForReason:(listenerName ?: @"libactivator.lockscreen.dismiss")
                                      completion:unlockBlock]) {
        HBLogWarn(@"Screen wake was not started for lock screen dismiss action %@", listenerName ?: @"");
        unlockBlock();
        return YES;
    }
    return YES;
}

- (BOOL)toggleLockScreenForListenerName:(NSString *)listenerName {
    SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
    if (!manager) {
        return NO;
    }
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        HBLogError(@"SBLockScreenManager does not support isUILocked for system action %@", listenerName ?: @"");
        return NO;
    }
    if ([manager isUILocked]) {
        [self dismissLockScreenForListenerName:listenerName];
    } else {
        [self showLockScreenForListenerName:listenerName];
    }
    return YES;
}

- (BOOL)lockAndWipeCredentialsForListenerName:(NSString *)listenerName {
    SBLockScreenManager *manager = [self lockScreenManagerForListenerName:listenerName];
    if (!manager) {
        return YES;
    }

    if ([manager respondsToSelector:@selector(lockUIFromSource:withOptions:completion:)]) {
        NSDictionary<NSString *, id> *options = @{
            LATLockOptionsUseScreenOffModeKey : @YES,
            LATLockOptionsForceBioLockoutKey : @YES,
            LATLockOptionsForceLockKey : @YES,
        };
        [manager lockUIFromSource:0 withOptions:options completion:nil];
        return YES;
    }

    HBLogError(@"SBLockScreenManager does not support biometric lockout options for system action %@",
               listenerName ?: @"");
    [self showLockScreenForListenerName:listenerName];
    return YES;
}

- (nullable SBLockScreenManager *)lockScreenManagerForListenerName:(NSString *)listenerName {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        HBLogError(@"SBLockScreenManager is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(id)managerClass sharedInstance];
}

@end
