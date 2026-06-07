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

@interface LAActivatorUnlockService ()
- (id<LAActivatorLockScreenManager>)lockScreenManager;
@end

@implementation LAActivatorUnlockService

#pragma mark - State

- (BOOL)isUILocked {
    id<LAActivatorLockScreenManager> manager = [self lockScreenManager];
    if ([manager respondsToSelector:@selector(isUILocked)]) {
        return [manager isUILocked];
    }
    return NO;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    id<LAActivatorLockScreenManager> manager = [self lockScreenManager];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        return NO;
    }
    return [manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)] ||
           [manager respondsToSelector:@selector(attemptUnlockWithPasscode:)];
}

#pragma mark - Private

- (id<LAActivatorLockScreenManager>)lockScreenManager {
    id<LAActivatorLockScreenManagerClass> managerClass = (id)NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return [managerClass sharedInstance];
}

@end
