//
//  LATFingerprintSensorEventSource.m
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATFingerprintSensorEventSource.h"

#import "LAActivator+Private.h"
#import "LATQueueAssertions.h"

#import <HBLog.h>

static NSTimeInterval const LATFingerprintSensorEventSourcePressDelay = 0.75;
static NSTimeInterval const LATFingerprintSensorEventSourceHoldDelay = 0.45;
static NSTimeInterval const LATFingerprintSensorEventSourceLongHoldDelay = 2.5;
static NSTimeInterval const LATFingerprintSensorEventSourceSlideInDelay = 1.0;
static NSTimeInterval const LATFingerprintSensorEventSourcePostUnlockIgnoreDelay = 0.25;

@interface LATFingerprintSensorEventSource ()

// Lifecycle
@property(nonatomic, assign, getter=isStarted) BOOL started;

// Touch ID state
@property(nonatomic, assign, getter=isSensorDown) BOOL sensorDown;
@property(nonatomic, assign, getter=isSecondPressDown) BOOL secondPressDown;
@property(nonatomic, assign, getter=isSequenceConsumed) BOOL sequenceConsumed;
@property(nonatomic, assign, getter=hasPendingSinglePress) BOOL pendingSinglePress;
@property(nonatomic, assign, getter=hasShortHoldRecognized) BOOL shortHoldRecognized;
@property(nonatomic, strong, nullable) LAEvent *shortHoldEventToAbort;

// Timer generations
@property(nonatomic, assign) NSUInteger holdGeneration;
@property(nonatomic, assign) NSUInteger singlePressGeneration;

// Timing
@property(nonatomic, assign) BOOL hasRecentDeviceUnlockTimestamp;
@property(nonatomic, assign) NSTimeInterval lastDeviceUnlockTimestamp;
@property(nonatomic, assign) NSTimeInterval lastSinglePressUpTimestamp;

@end

@implementation LATFingerprintSensorEventSource

#pragma mark - Lifecycle

- (void)start {
    LATAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;
}

#pragma mark - HID Events

- (void)noteHIDEvent:(IOHIDEventRef)event {
    LATAssertMainQueue();
    if (!self.started || !event || IOHIDEventGetType(event) != kIOHIDEventTypeTouchID) {
        return;
    }

    BOOL touchDown = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldTouchIDTouchDown) != 0;
    NSInteger sequenceState = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldTouchIDSequenceState);
    [self handleTouchIDDown:touchDown sequenceState:sequenceState timestamp:NSProcessInfo.processInfo.systemUptime];
}

#pragma mark - Runtime Coordination

- (void)noteDeviceUnlockedAtTimestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();

    self.hasRecentDeviceUnlockTimestamp = YES;
    self.lastDeviceUnlockTimestamp = timestamp;
    [self resetRecognitionState];
}

- (void)handleTouchIDDown:(BOOL)touchDown sequenceState:(NSInteger)sequenceState timestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();
    if (!self.started) {
        return;
    }

    if ([self shouldIgnoreTouchIDEventAtTimestamp:timestamp]) {
        [self resetRecognitionState];
        return;
    }

    if (touchDown) {
        [self handleSensorDownWithSequenceState:sequenceState timestamp:timestamp];
    } else {
        [self handleSensorUpWithSequenceState:sequenceState timestamp:timestamp];
    }
}

- (BOOL)shouldIgnoreTouchIDEventAtTimestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();

    if (!self.hasRecentDeviceUnlockTimestamp) {
        return NO;
    }

    NSTimeInterval elapsed = timestamp - self.lastDeviceUnlockTimestamp;
    return elapsed >= 0.0 && elapsed < LATFingerprintSensorEventSourcePostUnlockIgnoreDelay;
}

- (void)handleSensorDownWithSequenceState:(NSInteger)sequenceState timestamp:(__unused NSTimeInterval)timestamp {
    LATAssertMainQueue();
    if (self.sensorDown) {
        return;
    }

    self.sensorDown = YES;
    self.shortHoldRecognized = NO;
    self.sequenceConsumed = NO;
    [self clearShortHoldEventWithoutAborting];

    if (sequenceState == 1 && self.hasPendingSinglePress) {
        self.secondPressDown = YES;
        [self cancelPendingSinglePress];
    } else {
        self.secondPressDown = NO;
    }

    [self scheduleHoldRecognition];
}

- (void)handleSensorUpWithSequenceState:(NSInteger)sequenceState timestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();
    if (!self.sensorDown) {
        return;
    }

    BOOL wasSecondPressDown = self.secondPressDown;
    self.sensorDown = NO;
    self.secondPressDown = NO;
    [self cancelHoldRecognition];
    [self clearShortHoldEventWithoutAborting];

    if (self.sequenceConsumed || self.hasShortHoldRecognized) {
        [self resetSequenceIfIdle];
        return;
    }

    if (wasSecondPressDown || sequenceState >= 2) {
        [self cancelPendingSinglePress];
        self.sequenceConsumed = YES;
        [self sendFingerprintEventWithName:LAEventNameFingerprintSensorPressTwice];
        [self resetSequenceIfIdle];
        return;
    }

    [self scheduleSinglePressResolutionWithTimestamp:timestamp];
    [self resetSequenceIfIdle];
}

#pragma mark - Press Recognition

- (void)scheduleSinglePressResolutionWithTimestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();

    self.pendingSinglePress = YES;
    self.lastSinglePressUpTimestamp = timestamp;
    self.singlePressGeneration += 1;
    NSUInteger generation = self.singlePressGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATFingerprintSensorEventSourcePressDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf resolveSinglePressIfNeededWithGeneration:generation];
                   });
}

- (void)resolveSinglePressIfNeededWithGeneration:(NSUInteger)generation {
    LATAssertMainQueue();

    if (generation != self.singlePressGeneration || self.sensorDown || !self.hasPendingSinglePress ||
        self.sequenceConsumed) {
        return;
    }

    [self cancelPendingSinglePress];
    self.sequenceConsumed = YES;
    [self sendFingerprintEventWithName:LAEventNameFingerprintSensorPressSingle];
    [self resetSequenceIfIdle];
}

- (void)cancelPendingSinglePress {
    LATAssertMainQueue();

    self.singlePressGeneration += 1;
    self.pendingSinglePress = NO;
}

#pragma mark - Hold Recognition

- (void)scheduleHoldRecognition {
    LATAssertMainQueue();

    self.holdGeneration += 1;
    NSUInteger generation = self.holdGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATFingerprintSensorEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendShortHoldEventIfNeededWithGeneration:generation];
                   });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(LATFingerprintSensorEventSourceLongHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendLongHoldEventIfNeededWithGeneration:generation];
                   });
}

- (void)cancelHoldRecognition {
    LATAssertMainQueue();

    self.holdGeneration += 1;
}

- (void)sendShortHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LATAssertMainQueue();

    if (generation != self.holdGeneration || !self.sensorDown || self.sequenceConsumed) {
        return;
    }

    self.sequenceConsumed = YES;
    self.shortHoldRecognized = YES;
    NSString *eventName = self.secondPressDown ? LAEventNameFingerprintSensorPressSingleAndHold
                                               : LAEventNameFingerprintSensorHold;
    LAEvent *event = [self sendFingerprintEventWithName:eventName];
    self.shortHoldEventToAbort = event.handled ? event : nil;
}

- (void)sendLongHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LATAssertMainQueue();

    if (generation != self.holdGeneration || !self.sensorDown || self.secondPressDown || !self.hasShortHoldRecognized) {
        return;
    }

    self.shortHoldRecognized = NO;
    [self abortShortHoldEventIfNeeded];
    [self sendFingerprintEventWithName:LAEventNameFingerprintSensorHoldLong];
}

- (void)abortShortHoldEventIfNeeded {
    LATAssertMainQueue();

    LAEvent *event = self.shortHoldEventToAbort;
    self.shortHoldEventToAbort = nil;
    if (event) {
        [LASharedActivator sendAbortToListener:event];
    }
}

- (void)clearShortHoldEventWithoutAborting {
    LATAssertMainQueue();

    self.shortHoldEventToAbort = nil;
}

#pragma mark - Cross-Source Coordination

- (BOOL)consumePendingSinglePressForSlideInAtTimestamp:(NSTimeInterval)timestamp {
    LATAssertMainQueue();

    if (!self.started || self.sensorDown || !self.hasPendingSinglePress || self.sequenceConsumed) {
        return NO;
    }

    if (timestamp - self.lastSinglePressUpTimestamp < 0.0 ||
        timestamp - self.lastSinglePressUpTimestamp > LATFingerprintSensorEventSourceSlideInDelay) {
        return NO;
    }

    [self cancelPendingSinglePress];
    self.sequenceConsumed = YES;
    [self sendFingerprintEventWithName:LAEventNameFingerprintSensorPressSingleAndSlideIn];
    [self resetSequenceIfIdle];
    return YES;
}

#pragma mark - State

- (void)resetRecognitionState {
    LATAssertMainQueue();

    [self cancelPendingSinglePress];
    [self cancelHoldRecognition];
    [self clearShortHoldEventWithoutAborting];
    self.sensorDown = NO;
    self.secondPressDown = NO;
    self.sequenceConsumed = NO;
    self.shortHoldRecognized = NO;
    self.lastSinglePressUpTimestamp = 0.0;
}

- (void)resetSequenceIfIdle {
    LATAssertMainQueue();

    if (self.sensorDown || self.hasPendingSinglePress) {
        return;
    }

    self.sequenceConsumed = NO;
    self.secondPressDown = NO;
    self.shortHoldRecognized = NO;
    self.lastSinglePressUpTimestamp = 0.0;
}

#pragma mark - Event Dispatch

- (LAEvent *)sendFingerprintEventWithName:(NSString *)eventName {
    LATAssertMainQueue();

    LAEvent *event = [LAEvent eventWithName:eventName mode:[self currentEventMode]];
    [LASharedActivator sendEventToListener:event];
    HBLogInfo(@"Dispatched fingerprint sensor event=%@", eventName);
    return event;
}

- (NSString *)currentEventMode {
    LATAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

#if DEBUG
#pragma mark - Testing Hooks

- (void)la_testingNoteTouchIDDown:(BOOL)touchDown
                    sequenceState:(NSInteger)sequenceState
                        timestamp:(NSTimeInterval)timestamp {
    [self handleTouchIDDown:touchDown sequenceState:sequenceState timestamp:timestamp];
}

- (void)la_testingResolvePendingSinglePress {
    [self resolveSinglePressIfNeededWithGeneration:self.singlePressGeneration];
}

- (void)la_testingSendShortHoldIfNeeded {
    [self sendShortHoldEventIfNeededWithGeneration:self.holdGeneration];
}

- (void)la_testingSendLongHoldIfNeeded {
    [self sendLongHoldEventIfNeededWithGeneration:self.holdGeneration];
}
#endif

@end
