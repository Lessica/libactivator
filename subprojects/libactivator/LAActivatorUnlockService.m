//
//  LAActivatorUnlockService.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorUnlockService.h"

@protocol LAActivatorLockScreenManagerClass <NSObject>
+ (id)sharedInstance;
@end

@protocol LAActivatorLockScreenManager <NSObject>
@optional
- (BOOL)isUILocked;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)finishUIUnlock completion:(id)completion;
@end

@protocol LAActivatorBacklightControllerClass <NSObject>
+ (id)sharedInstance;
@end

@protocol LAActivatorBacklightController <NSObject>
@optional
- (void)turnOnScreenFullyWithBacklightSource:(NSInteger)source;
@end

@implementation LAActivatorUnlockService

#pragma mark - State

- (BOOL)isUILocked {
    __block BOOL locked = NO;
    [self performOnMainThreadSynchronously:^{
        id<LAActivatorLockScreenManager> manager = [self lockScreenManager];
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
        id<LAActivatorLockScreenManager> manager = [self lockScreenManager];
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
    [self performOnMainThreadSynchronously:^{
        id<LAActivatorBacklightController> backlightController = [self backlightController];
        if ([backlightController respondsToSelector:@selector(turnOnScreenFullyWithBacklightSource:)]) {
            [backlightController turnOnScreenFullyWithBacklightSource:1];
        }

        id<LAActivatorLockScreenManager> manager = [self lockScreenManager];
        if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
            [manager attemptUnlockWithPasscode:passcode ?: @"" finishUIUnlock:YES completion:nil];
            attempted = YES;
        } else if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
            [manager attemptUnlockWithPasscode:passcode ?: @""];
            attempted = YES;
        }
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

- (id<LAActivatorLockScreenManager>)lockScreenManager {
    id<LAActivatorLockScreenManagerClass> managerClass = (id)NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return [managerClass sharedInstance];
}

- (id<LAActivatorBacklightController>)backlightController {
    id<LAActivatorBacklightControllerClass> controllerClass = (id)NSClassFromString(@"SBBacklightController");
    if (![controllerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return [controllerClass sharedInstance];
}

@end
