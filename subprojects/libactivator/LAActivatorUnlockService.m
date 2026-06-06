//
//  LAActivatorUnlockService.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorUnlockService.h"

#import <objc/message.h>

@interface LAActivatorUnlockService ()
- (id)lockScreenManager;
@end

@implementation LAActivatorUnlockService {
    BOOL _runningInsideSpringBoard;
}

#pragma mark - Lifecycle

- (instancetype)initWithSpringBoardRole:(BOOL)runningInsideSpringBoard {
    self = [super init];
    if (self) {
        _runningInsideSpringBoard = runningInsideSpringBoard;
    }
    return self;
}

#pragma mark - State

- (BOOL)isUILocked {
    id manager = [self lockScreenManager];
    if ([manager respondsToSelector:@selector(isUILocked)]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(manager, @selector(isUILocked));
    }
    return NO;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    id manager = [self lockScreenManager];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        return NO;
    }
    return [manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)] ||
           [manager respondsToSelector:@selector(attemptUnlockWithPasscode:)];
}

#pragma mark - Private

- (id)lockScreenManager {
    if (!_runningInsideSpringBoard) {
        return nil;
    }

    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return ((id (*)(Class, SEL))objc_msgSend)(managerClass, @selector(sharedInstance));
}

@end
