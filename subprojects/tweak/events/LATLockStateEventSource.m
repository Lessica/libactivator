//
//  LATLockStateEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATLockStateEventSource.h"

#import "LAActivator+Private.h"

#import <HBLog.h>
#import <notify.h>

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface LATLockStateEventSource ()
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) BOOL hasKnownLockState;
@property(nonatomic, assign, getter=isUILocked) BOOL uiLocked;
@property(nonatomic, assign) int lockStateToken;
@end

@implementation LATLockStateEventSource

#pragma mark - Lifecycle

- (void)start {
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownLockStateWithoutSendingEvent];

    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.apple.springboard.lockstate", &_lockStateToken, dispatch_get_main_queue(), ^(int token) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf handleLockStateNotification];
    });
}

#pragma mark - Notifications

- (void)handleLockStateNotification {
    [LASharedActivator la_noteRuntimeStateMayHaveChanged];

    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        HBLogDebug(@"Unable to read lock state for device lock event source");
        return;
    }

    if (!self.hasKnownLockState) {
        self.hasKnownLockState = YES;
        self.uiLocked = locked;
        return;
    }

    if (self.uiLocked == locked) {
        return;
    }

    self.uiLocked = locked;
    [self sendDeviceLockEventForLockedState:locked];
}

- (void)refreshKnownLockStateWithoutSendingEvent {
    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        return;
    }
    self.hasKnownLockState = YES;
    self.uiLocked = locked;
}

#pragma mark - State

- (BOOL)readUILocked:(BOOL *)locked {
    __block BOOL didRead = NO;
    __block BOOL uiLocked = NO;
    dispatch_block_t readBlock = ^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
            return;
        }

        SBLockScreenManager *manager = [(id)managerClass sharedInstance];
        if (![manager respondsToSelector:@selector(isUILocked)]) {
            return;
        }

        uiLocked = [manager isUILocked];
        didRead = YES;
    };

    if ([NSThread isMainThread]) {
        readBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), readBlock);
    }

    if (didRead && locked) {
        *locked = uiLocked;
    }
    return didRead;
}

#pragma mark - Event Dispatch

- (void)sendDeviceLockEventForLockedState:(BOOL)locked {
    NSString *eventName = locked ? LAEventNameDeviceLocked : LAEventNameDeviceUnlocked;
    NSString *eventMode = locked ? LAEventModeLockScreen : LASharedActivator.currentEventMode;
    if (!locked && [eventMode isEqualToString:LAEventModeLockScreen]) {
        eventMode = LASharedActivator.currentEventModeUnderneathLockScreen;
    }
    if (eventMode.length == 0 || (!locked && [eventMode isEqualToString:LAEventModeLockScreen])) {
        eventMode = locked ? LAEventModeLockScreen : LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
