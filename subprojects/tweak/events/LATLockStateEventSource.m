//
//  LATLockStateEventSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATLockStateEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATRuntimeStateSource.h"

#import <HBLog.h>
#import <notify.h>

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface LATLockStateEventSource ()

// Dependencies
@property(nonatomic, strong) LATRuntimeStateSource *runtimeStateSource;

// Lifecycle and notification token
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) int lockStateToken;

// Lock state
@property(nonatomic, assign) BOOL hasKnownLockState;
@property(nonatomic, assign, getter=isUILocked) BOOL uiLocked;

@end

@implementation LATLockStateEventSource

#pragma mark - Lifecycle

- (instancetype)initWithRuntimeStateSource:(LATRuntimeStateSource *)runtimeStateSource {
    self = [super init];
    if (self) {
        _runtimeStateSource = runtimeStateSource;
    }
    return self;
}

- (void)dealloc {
    if (_lockStateToken != 0) {
        notify_cancel(_lockStateToken);
    }
}

- (void)start {
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownLockStateWithoutSendingEvent];

    __weak typeof(self) weakSelf = self;
    int status = notify_register_dispatch("com.apple.springboard.lockstate", &_lockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                              (void)token;
                                              __strong typeof(weakSelf) strongSelf = weakSelf;
                                              [strongSelf handleLockStateNotification];
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogWarn(@"Unable to observe lock state: %d", status);
        _lockStateToken = 0;
    }
}

#pragma mark - Notifications

- (void)handleLockStateNotification {
    LAAssertMainQueue();
    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        HBLogDebug(@"Unable to read lock state for device lock event source");
        return;
    }
    [self.runtimeStateSource noteUILocked:locked];

    if (!self.hasKnownLockState) {
        self.hasKnownLockState = YES;
        self.uiLocked = locked;
        return;
    }

    if (self.uiLocked == locked) {
        return;
    }

    self.uiLocked = locked;
    if (!locked) {
        [self.fingerprintSensorEventSource noteDeviceUnlockedAtTimestamp:NSProcessInfo.processInfo.systemUptime];
    }
    [self sendDeviceLockEventForLockedState:locked];
}

- (void)refreshKnownLockStateWithoutSendingEvent {
    LAAssertMainQueue();
    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        return;
    }
    self.hasKnownLockState = YES;
    self.uiLocked = locked;
    [self.runtimeStateSource noteUILocked:locked];
}

#pragma mark - State

- (BOOL)readUILocked:(BOOL *)locked {
    LAAssertMainQueue();
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
    LAAssertMainQueue();
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
