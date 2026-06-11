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

#define kLATLockStateEventSourceMainQueueReason @"LATLockStateEventSource must only be used on the main thread"

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
    NSAssert(NSThread.isMainThread, kLATLockStateEventSourceMainQueueReason);
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownLockStateWithoutSendingEvent];

    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("com.apple.springboard.lockstate", &_lockStateToken, dispatch_get_main_queue(),
                             ^(int token) {
                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                 [strongSelf handleLockStateNotification];
                             });
}

#pragma mark - Notifications

- (void)handleLockStateNotification {
    NSAssert(NSThread.isMainThread, kLATLockStateEventSourceMainQueueReason);
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
    NSAssert(NSThread.isMainThread, kLATLockStateEventSourceMainQueueReason);
    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        return;
    }
    self.hasKnownLockState = YES;
    self.uiLocked = locked;
}

#pragma mark - State

- (BOOL)readUILocked:(BOOL *)locked {
    NSAssert(NSThread.isMainThread, kLATLockStateEventSourceMainQueueReason);
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return NO;
    }

    SBLockScreenManager *manager = [(id)managerClass sharedInstance];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        return NO;
    }

    if (locked) {
        *locked = [manager isUILocked];
    }
    return YES;
}

#pragma mark - Event Dispatch

- (void)sendDeviceLockEventForLockedState:(BOOL)locked {
    NSAssert(NSThread.isMainThread, kLATLockStateEventSourceMainQueueReason);
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
