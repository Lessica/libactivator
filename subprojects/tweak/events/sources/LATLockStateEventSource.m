//
//  LATLockStateEventSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATLockStateEventSource.h"

#import "LAQueueAssertions.h"

#import <HBLog.h>
#import <notify.h>

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface LATLockStateEventSource ()

// Dependencies
@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, strong) id<LATRuntimeLockStateUpdating> lockStateUpdater;
@property(nonatomic, weak, nullable) id<LATFingerprintGestureCoordinating> fingerprintCoordinator;

// Lifecycle and notification token
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign) int lockStateToken;

// Lock state
@property(nonatomic, assign) BOOL hasKnownLockState;
@property(nonatomic, assign, getter=isUILocked) BOOL uiLocked;

@end

@implementation LATLockStateEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    id<LATFingerprintGestureCoordinating> fingerprintCoordinator =
        [context eventSourceConformingToProtocol:@protocol(LATFingerprintGestureCoordinating)];
    return [self initWithEventDispatcher:context.eventDispatcher
                            modeProvider:context.eventDispatcher
                        lockStateUpdater:context.runtimeLockStateUpdater
                  fingerprintCoordinator:fingerprintCoordinator];
}

- (NSString *)eventSourceIdentifier {
    return @"lock-state";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameDeviceLocked,
        LAEventNameDeviceUnlocked,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                       lockStateUpdater:(id<LATRuntimeLockStateUpdating>)lockStateUpdater
                 fingerprintCoordinator:(id<LATFingerprintGestureCoordinating>)fingerprintCoordinator {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);
    NSParameterAssert(lockStateUpdater);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _lockStateUpdater = lockStateUpdater;
        _fingerprintCoordinator = fingerprintCoordinator;
    }
    return self;
}

- (void)dealloc {
    [self cancelLockStateObservation];
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
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

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self cancelLockStateObservation];
    self.hasKnownLockState = NO;
    self.uiLocked = NO;
}

- (void)cancelLockStateObservation {
    if (_lockStateToken == 0) {
        return;
    }
    notify_cancel(_lockStateToken);
    _lockStateToken = 0;
}

#pragma mark - Notifications

- (void)handleLockStateNotification {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    BOOL locked = NO;
    if (![self readUILocked:&locked]) {
        HBLogDebug(@"Unable to read lock state for device lock event source");
        return;
    }
    [self.lockStateUpdater noteUILocked:locked];

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
        [self.fingerprintCoordinator noteDeviceUnlockedAtTimestamp:NSProcessInfo.processInfo.systemUptime];
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
    [self.lockStateUpdater noteUILocked:locked];
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
    NSString *eventMode = locked ? LAEventModeLockScreen : self.modeProvider.currentEventMode;
    if (!locked && [eventMode isEqualToString:LAEventModeLockScreen]) {
        eventMode = self.modeProvider.currentEventModeUnderneathLockScreen;
    }
    if (eventMode.length == 0 || (!locked && [eventMode isEqualToString:LAEventModeLockScreen])) {
        eventMode = locked ? LAEventModeLockScreen : LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
}

@end
