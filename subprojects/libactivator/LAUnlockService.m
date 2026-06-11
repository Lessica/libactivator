//
//  LAUnlockService.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAUnlockService.h"
#import "LAActivator+Private.h"

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode
                   finishUIUnlock:(BOOL)finishUIUnlock
                       completion:(nullable id)completion;
@end

@implementation LAUnlockService

#pragma mark - State

- (BOOL)isUILocked {
    __block BOOL locked = NO;
    [self performOnMainThreadSynchronously:^{
        SBLockScreenManager *manager = [self lockScreenManager];
        if ([manager respondsToSelector:@selector(isUILocked)]) {
            locked = [manager isUILocked];
        }
    }];
    return locked;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return [self canRequestUnlock];
}

- (BOOL)canRequestUnlock {
    __block BOOL canRequest = NO;
    [self performOnMainThreadSynchronously:^{
        SBLockScreenManager *manager = [self lockScreenManager];
        if (![manager respondsToSelector:@selector(isUILocked)]) {
            return;
        }
        canRequest = [manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)] ||
                     [manager respondsToSelector:@selector(attemptUnlockWithPasscode:)];
    }];
    return canRequest;
}

- (BOOL)requestUnlockWithPasscode:(NSString *)passcode {
    __block BOOL attempted = NO;
    NSString *passcodeToUse = [passcode copy] ?: @"";
    [self performOnMainThreadSynchronously:^{
        if (![LAActivator.sharedInstance la_screenIsOn]) {
            attempted =
                [LAActivator.sharedInstance la_wakeScreenForReason:@"unlock request"
                                                        completion:^{
                                                            [self attemptUnlockOnMainThreadWithPasscode:passcodeToUse];
                                                        }];
            return;
        }

        attempted = [self attemptUnlockOnMainThreadWithPasscode:passcodeToUse];
    }];
    return attempted;
}

#pragma mark - Private

- (void)performOnMainThreadSynchronously:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), block);
}

- (SBLockScreenManager *)lockScreenManager {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return [(id)managerClass sharedInstance];
}

- (BOOL)attemptUnlockOnMainThreadWithPasscode:(NSString *)passcode {
    SBLockScreenManager *manager = [self lockScreenManager];
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @"" finishUIUnlock:YES completion:nil];
        return YES;
    }
    if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
        [manager attemptUnlockWithPasscode:passcode ?: @""];
        return YES;
    }
    return NO;
}

@end
