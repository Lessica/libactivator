//
//  LATButtonEventSource.m
//  libactivator
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATButtonEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"

static NSTimeInterval const LATButtonEventSourceHoldDelay = 0.45;
static NSTimeInterval const LATButtonEventSourceMenuLongHoldDelay = 2.5;
static NSTimeInterval const LATButtonEventSourceLockLongHoldDelay = 2.5;
static NSTimeInterval const LATButtonEventSourceRingerToggleTwiceDelay = 1.0;

static uint64_t const LATButtonEventSourceSyntheticSenderIDMask = 0x8000000000000000;

@interface LATButtonEventSource ()

// Lifecycle
@property(nonatomic, assign) BOOL started;

// Button states
@property(nonatomic, assign, getter=isButtonSequenceConsumed) BOOL buttonSequenceConsumed;
@property(nonatomic, assign, getter=isLockButtonDown) BOOL lockButtonDown;
@property(nonatomic, assign, getter=isMenuButtonDown) BOOL menuButtonDown;
@property(nonatomic, assign, getter=isVolumeDownButtonDown) BOOL volumeDownButtonDown;
@property(nonatomic, assign, getter=isVolumeUpButtonDown) BOOL volumeUpButtonDown;

// Lock button recognition
@property(nonatomic, assign) NSUInteger lockHoldGeneration;
@property(nonatomic, assign) NSUInteger lockPressCount;
@property(nonatomic, assign) NSUInteger lockPressGeneration;
@property(nonatomic, assign) BOOL lockShortHoldRecognized;
@property(nonatomic, strong, nullable) LAEvent *lockHoldShortEventToAbort;

// Menu button recognition
@property(nonatomic, assign) NSUInteger menuHoldGeneration;
@property(nonatomic, assign) NSUInteger menuPressCount;
@property(nonatomic, assign) NSUInteger menuPressGeneration;
@property(nonatomic, assign) BOOL menuShortHoldRecognized;
@property(nonatomic, strong, nullable) LAEvent *menuHoldShortEventToAbort;

// Volume button recognition
@property(nonatomic, assign) NSUInteger volumeDownHoldGeneration;
@property(nonatomic, assign) NSUInteger volumeUpHoldGeneration;
@property(nonatomic, assign) CFIndex lastVolumePressUsage;
@property(nonatomic, assign) CFAbsoluteTime lastVolumePressTime;

// Ringer switch tracking
@property(nonatomic, assign) CFAbsoluteTime lastRingerSwitchTime;

@end

@implementation LATButtonEventSource

#pragma mark - Lifecycle

- (void)start {
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;
}

#pragma mark - HID Events

- (void)noteHIDEvent:(IOHIDEventRef)event {
    LAAssertMainQueue();
    if (!self.started || !event) {
        return;
    }

    if ((IOHIDEventGetSenderID(event) & LATButtonEventSourceSyntheticSenderIDMask) != 0) {
        return;
    }

    if (IOHIDEventGetType(event) != kIOHIDEventTypeKeyboard) {
        return;
    }

    CFIndex usagePage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsagePage);
    CFIndex usage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
    BOOL keyDown = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) != 0;
    if (usagePage == kHIDPage_Telephony && usage == kHIDUsage_Telephony_Mute) {
        [self handleRingerSwitchIsUnmuted:keyDown];
        return;
    }

    if (usagePage != kHIDPage_Consumer) {
        return;
    }

    [self handleConsumerKeyboardUsage:usage keyDown:keyDown];
}

- (void)handleConsumerKeyboardUsage:(CFIndex)usage keyDown:(BOOL)keyDown {
    LAAssertMainQueue();

    switch (usage) {
    case kHIDUsage_Csmr_Power:
        [self handleLockButtonDown:keyDown];
        break;
    case kHIDUsage_Csmr_Menu:
        [self handleMenuButtonDown:keyDown];
        break;
    case kHIDUsage_Csmr_VolumeIncrement:
        [self handleVolumeUpButtonDown:keyDown];
        break;
    case kHIDUsage_Csmr_VolumeDecrement:
        [self handleVolumeDownButtonDown:keyDown];
        break;
    default:
        break;
    }
}

- (void)handleLockButtonDown:(BOOL)keyDown {
    LAAssertMainQueue();

    if (keyDown) {
        if (self.lockButtonDown) {
            return;
        }
        self.lockButtonDown = YES;
        [self scheduleLockHoldRecognition];
        [self sendLockMenuPressIfNeeded];
        return;
    }

    if (!self.lockButtonDown) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    self.lockButtonDown = NO;
    [self cancelLockHoldRecognition];
    [self clearLockHoldShortEventWithoutAborting];
    if (!self.buttonSequenceConsumed) {
        [self noteLockPressRelease];
    }
    [self resetButtonSequenceConsumedIfNoButtonsAreDown];
}

- (void)handleVolumeUpButtonDown:(BOOL)keyDown {
    LAAssertMainQueue();

    if (keyDown) {
        if (self.volumeUpButtonDown) {
            return;
        }
        self.volumeUpButtonDown = YES;
        [self scheduleVolumeUpHoldRecognition];
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeUpPressWithMenu];
        [self sendVolumeBothPressIfNeeded];
        return;
    }

    if (!self.volumeUpButtonDown) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    self.volumeUpButtonDown = NO;
    [self cancelVolumeUpHoldRecognition];
    if (self.buttonSequenceConsumed) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    [self sendVolumePressOrSequenceWithPressEventName:LAEventNameVolumeUpPress usage:kHIDUsage_Csmr_VolumeIncrement];
}

- (void)handleVolumeDownButtonDown:(BOOL)keyDown {
    LAAssertMainQueue();

    if (keyDown) {
        if (self.volumeDownButtonDown) {
            return;
        }
        self.volumeDownButtonDown = YES;
        [self scheduleVolumeDownHoldRecognition];
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeDownPressWithMenu];
        [self sendVolumeBothPressIfNeeded];
        return;
    }

    if (!self.volumeDownButtonDown) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    self.volumeDownButtonDown = NO;
    [self cancelVolumeDownHoldRecognition];
    if (self.buttonSequenceConsumed) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    [self sendVolumePressOrSequenceWithPressEventName:LAEventNameVolumeDownPress usage:kHIDUsage_Csmr_VolumeDecrement];
}

- (void)handleMenuButtonDown:(BOOL)keyDown {
    LAAssertMainQueue();

    if (keyDown) {
        if (self.menuButtonDown) {
            return;
        }
        self.menuButtonDown = YES;
        [self scheduleMenuHoldRecognition];
        [self sendVolumeMenuPressForCurrentVolumeButtonIfNeeded];
        [self sendLockMenuPressIfNeeded];
        return;
    }

    if (!self.menuButtonDown) {
        [self resetButtonSequenceConsumedIfNoButtonsAreDown];
        return;
    }
    self.menuButtonDown = NO;
    [self cancelMenuHoldRecognition];
    [self clearMenuHoldShortEventWithoutAborting];
    if (!self.buttonSequenceConsumed) {
        [self noteMenuPressRelease];
    }
    [self resetButtonSequenceConsumedIfNoButtonsAreDown];
}

- (void)sendLockMenuPressIfNeeded {
    LAAssertMainQueue();

    if (self.buttonSequenceConsumed || !self.lockButtonDown || !self.menuButtonDown) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:LAEventNameLockPressWithMenu];
}

- (void)sendVolumeBothPressIfNeeded {
    LAAssertMainQueue();

    if (self.buttonSequenceConsumed || !self.volumeUpButtonDown || !self.volumeDownButtonDown) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:LAEventNameVolumeBothPress];
}

- (void)sendVolumeMenuPressForCurrentVolumeButtonIfNeeded {
    LAAssertMainQueue();

    if (self.volumeUpButtonDown && !self.volumeDownButtonDown) {
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeUpPressWithMenu];
    } else if (self.volumeDownButtonDown && !self.volumeUpButtonDown) {
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeDownPressWithMenu];
    }
}

- (void)sendVolumeMenuPressIfNeededWithEventName:(NSString *)eventName {
    LAAssertMainQueue();

    if (self.buttonSequenceConsumed || !self.menuButtonDown ||
        (!self.volumeUpButtonDown && !self.volumeDownButtonDown)) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:eventName];
}

- (void)resetButtonSequenceConsumedIfNoButtonsAreDown {
    LAAssertMainQueue();

    if (!self.lockButtonDown && !self.menuButtonDown && !self.volumeUpButtonDown && !self.volumeDownButtonDown) {
        self.buttonSequenceConsumed = NO;
    }
}

#pragma mark - Lock Press Recognition

- (void)noteLockPressRelease {
    LAAssertMainQueue();

    if (![self shouldRecognizeLockPressSequence]) {
        [self cancelLockPressRecognition];
        return;
    }

    self.lockPressCount += 1;
    if (self.lockPressCount == 1) {
        [self scheduleLockPressResolutionForPressCount:1];
        return;
    }

    if (self.lockPressCount == 2) {
        if ([self hasAssignedListenerForEventName:LAEventNameLockPressTriple]) {
            [self scheduleLockPressResolutionForPressCount:2];
        } else {
            [self cancelLockPressRecognition];
            [self sendButtonEventWithName:LAEventNameLockPressDouble];
        }
        return;
    }

    [self cancelLockPressRecognition];
    [self sendButtonEventWithName:LAEventNameLockPressTriple];
}

- (void)scheduleLockPressResolutionForPressCount:(NSUInteger)pressCount {
    LAAssertMainQueue();

    self.lockPressGeneration += 1;
    NSUInteger generation = self.lockPressGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf resolveLockPressSequenceWithPressCount:pressCount generation:generation];
                   });
}

- (void)resolveLockPressSequenceWithPressCount:(NSUInteger)pressCount generation:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.lockPressGeneration || self.lockButtonDown || self.buttonSequenceConsumed ||
        self.lockPressCount != pressCount) {
        return;
    }

    [self cancelLockPressRecognition];
    if (pressCount == 2 && [self hasAssignedListenerForEventName:LAEventNameLockPressDouble]) {
        [self sendButtonEventWithName:LAEventNameLockPressDouble];
    }
}

- (BOOL)shouldRecognizeLockPressSequence {
    LAAssertMainQueue();

    return [self hasAssignedListenerForEventName:LAEventNameLockPressDouble] ||
           [self hasAssignedListenerForEventName:LAEventNameLockPressTriple];
}

- (void)cancelLockPressRecognition {
    LAAssertMainQueue();

    self.lockPressGeneration += 1;
    self.lockPressCount = 0;
}

#pragma mark - Menu Press Recognition

- (void)noteMenuPressRelease {
    LAAssertMainQueue();

    if (![self shouldDelayMenuSinglePress]) {
        [self cancelMenuPressRecognition];
        [self sendMenuSinglePressEvent];
        return;
    }

    self.menuPressCount += 1;
    if (self.menuPressCount == 1) {
        [self scheduleMenuPressResolutionForPressCount:1];
        return;
    }

    if (self.menuPressCount == 2) {
        if ([self hasAssignedListenerForEventName:LAEventNameMenuPressTriple]) {
            [self scheduleMenuPressResolutionForPressCount:2];
        } else {
            [self cancelMenuPressRecognition];
            [self sendButtonEventWithName:LAEventNameMenuPressDouble];
        }
        return;
    }

    [self cancelMenuPressRecognition];
    [self sendButtonEventWithName:LAEventNameMenuPressTriple];
}

- (void)scheduleMenuPressResolutionForPressCount:(NSUInteger)pressCount {
    LAAssertMainQueue();

    self.menuPressGeneration += 1;
    NSUInteger generation = self.menuPressGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf resolveMenuPressSequenceWithPressCount:pressCount generation:generation];
                   });
}

- (void)resolveMenuPressSequenceWithPressCount:(NSUInteger)pressCount generation:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.menuPressGeneration || self.menuButtonDown || self.buttonSequenceConsumed ||
        self.menuPressCount != pressCount) {
        return;
    }

    [self cancelMenuPressRecognition];
    if (pressCount == 1) {
        [self sendMenuSinglePressEvent];
    } else if (pressCount == 2) {
        [self sendButtonEventWithName:LAEventNameMenuPressDouble];
    }
}

- (BOOL)shouldDelayMenuSinglePress {
    LAAssertMainQueue();

    return [self hasAssignedListenerForEventName:LAEventNameMenuPressDouble] ||
           [self hasAssignedListenerForEventName:LAEventNameMenuPressTriple];
}

- (BOOL)hasAssignedListenerForEventName:(NSString *)eventName {
    LAAssertMainQueue();

    NSString *eventMode = [self currentEventMode];
    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    return [LASharedActivator listenerForEvent:event] != nil;
}

- (void)cancelMenuPressRecognition {
    LAAssertMainQueue();

    self.menuPressGeneration += 1;
    self.menuPressCount = 0;
}

#pragma mark - Volume Sequence Recognition

- (void)sendVolumePressOrSequenceWithPressEventName:(NSString *)pressEventName usage:(CFIndex)usage {
    LAAssertMainQueue();

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - self.lastVolumePressTime > LATButtonEventSourceHoldDelay) {
        self.lastVolumePressUsage = usage;
        self.lastVolumePressTime = currentTime;
        [self sendButtonEventWithName:pressEventName];
        return;
    }

    NSString *sequenceEventName = nil;
    if (self.lastVolumePressUsage == kHIDUsage_Csmr_VolumeIncrement && usage == kHIDUsage_Csmr_VolumeDecrement) {
        sequenceEventName = LAEventNameVolumeUpDown;
    } else if (self.lastVolumePressUsage == kHIDUsage_Csmr_VolumeDecrement && usage == kHIDUsage_Csmr_VolumeIncrement) {
        sequenceEventName = LAEventNameVolumeDownUp;
    }

    self.lastVolumePressUsage = 0;
    self.lastVolumePressTime = 0.0;
    if (sequenceEventName.length > 0) {
        [self sendButtonEventWithName:sequenceEventName];
        return;
    }
}

#pragma mark - Ringer Switch Recognition

- (void)handleRingerSwitchIsUnmuted:(BOOL)isUnmuted {
    LAAssertMainQueue();

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    BOOL toggledTwice = currentTime - self.lastRingerSwitchTime < LATButtonEventSourceRingerToggleTwiceDelay;
    self.lastRingerSwitchTime = currentTime;

    [self sendButtonEventWithName:isUnmuted ? LAEventNameVolumeMuteOff : LAEventNameVolumeMuteOn];
    if (toggledTwice) {
        [self sendButtonEventWithName:LAEventNameVolumeToggleMuteTwice];
    }
}

#pragma mark - Hold Recognition

- (void)scheduleVolumeUpHoldRecognition {
    LAAssertMainQueue();

    self.volumeUpHoldGeneration += 1;
    NSUInteger generation = self.volumeUpHoldGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendVolumeHoldEventIfNeededWithName:LAEventNameVolumeUpHoldShort
                                                             keyIsDown:strongSelf.isVolumeUpButtonDown
                                                            generation:generation
                                                     currentGeneration:strongSelf.volumeUpHoldGeneration];
                   });
}

- (void)scheduleVolumeDownHoldRecognition {
    LAAssertMainQueue();

    self.volumeDownHoldGeneration += 1;
    NSUInteger generation = self.volumeDownHoldGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendVolumeHoldEventIfNeededWithName:LAEventNameVolumeDownHoldShort
                                                             keyIsDown:strongSelf.isVolumeDownButtonDown
                                                            generation:generation
                                                     currentGeneration:strongSelf.volumeDownHoldGeneration];
                   });
}

- (void)cancelVolumeUpHoldRecognition {
    LAAssertMainQueue();
    self.volumeUpHoldGeneration += 1;
}

- (void)cancelVolumeDownHoldRecognition {
    LAAssertMainQueue();
    self.volumeDownHoldGeneration += 1;
}

- (void)cancelVolumeHoldRecognition {
    LAAssertMainQueue();
    [self cancelVolumeUpHoldRecognition];
    [self cancelVolumeDownHoldRecognition];
}

- (void)scheduleLockHoldRecognition {
    LAAssertMainQueue();

    self.lockHoldGeneration += 1;
    self.lockShortHoldRecognized = NO;
    [self clearLockHoldShortEventWithoutAborting];
    NSUInteger generation = self.lockHoldGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendLockShortHoldEventIfNeededWithGeneration:generation];
                   });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceLockLongHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendLockLongHoldEventIfNeededWithGeneration:generation];
                   });
}

- (void)cancelLockHoldRecognition {
    LAAssertMainQueue();

    self.lockHoldGeneration += 1;
    self.lockShortHoldRecognized = NO;
}

- (void)scheduleMenuHoldRecognition {
    LAAssertMainQueue();

    self.menuHoldGeneration += 1;
    self.menuShortHoldRecognized = NO;
    [self clearMenuHoldShortEventWithoutAborting];
    NSUInteger generation = self.menuHoldGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendMenuShortHoldEventIfNeededWithGeneration:generation];
                   });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATButtonEventSourceMenuLongHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       [strongSelf sendMenuLongHoldEventIfNeededWithGeneration:generation];
                   });
}

- (void)cancelMenuHoldRecognition {
    LAAssertMainQueue();

    self.menuHoldGeneration += 1;
    self.menuShortHoldRecognized = NO;
}

- (void)sendVolumeHoldEventIfNeededWithName:(NSString *)eventName
                                  keyIsDown:(BOOL)keyIsDown
                                 generation:(NSUInteger)generation
                          currentGeneration:(NSUInteger)currentGeneration {
    LAAssertMainQueue();

    if (generation != currentGeneration || !keyIsDown || self.buttonSequenceConsumed) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:eventName];
}

- (void)consumeButtonSequence {
    LAAssertMainQueue();

    self.buttonSequenceConsumed = YES;
    [self cancelLockHoldRecognition];
    [self cancelLockPressRecognition];
    [self clearLockHoldShortEventWithoutAborting];
    [self cancelVolumeHoldRecognition];
    [self cancelMenuHoldRecognition];
    [self cancelMenuPressRecognition];
    [self clearMenuHoldShortEventWithoutAborting];
    self.lastVolumePressUsage = 0;
    self.lastVolumePressTime = 0.0;
}

- (void)sendLockShortHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.lockHoldGeneration || !self.lockButtonDown || self.buttonSequenceConsumed) {
        return;
    }

    self.buttonSequenceConsumed = YES;
    self.lockShortHoldRecognized = YES;
    [self cancelLockPressRecognition];
    LAEvent *event = [self sendButtonEventWithName:LAEventNameLockHoldShort];
    self.lockHoldShortEventToAbort = event.handled ? event : nil;
}

- (void)sendLockLongHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.lockHoldGeneration || !self.lockButtonDown || !self.lockShortHoldRecognized) {
        return;
    }

    self.buttonSequenceConsumed = YES;
    self.lockShortHoldRecognized = NO;
    [self cancelLockPressRecognition];
    [self abortLockHoldShortEventIfNeeded];
    [self sendButtonEventWithName:LAEventNameLockHoldLong];
}

- (void)abortLockHoldShortEventIfNeeded {
    LAAssertMainQueue();

    LAEvent *event = self.lockHoldShortEventToAbort;
    self.lockHoldShortEventToAbort = nil;
    if (event) {
        [LASharedActivator sendAbortToListener:event];
    }
}

- (void)clearLockHoldShortEventWithoutAborting {
    LAAssertMainQueue();

    self.lockHoldShortEventToAbort = nil;
}

- (void)sendMenuShortHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.menuHoldGeneration || !self.menuButtonDown || self.buttonSequenceConsumed) {
        return;
    }

    self.buttonSequenceConsumed = YES;
    self.menuShortHoldRecognized = YES;
    [self cancelMenuPressRecognition];
    LAEvent *event = [self sendButtonEventWithName:LAEventNameMenuHoldShort];
    self.menuHoldShortEventToAbort = event.handled ? event : nil;
}

- (void)sendMenuLongHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    LAAssertMainQueue();

    if (generation != self.menuHoldGeneration || !self.menuButtonDown || !self.menuShortHoldRecognized) {
        return;
    }

    self.buttonSequenceConsumed = YES;
    self.menuShortHoldRecognized = NO;
    [self cancelMenuPressRecognition];
    [self abortMenuHoldShortEventIfNeeded];
    [self sendButtonEventWithName:LAEventNameMenuHoldLong];
}

- (void)abortMenuHoldShortEventIfNeeded {
    LAAssertMainQueue();

    LAEvent *event = self.menuHoldShortEventToAbort;
    self.menuHoldShortEventToAbort = nil;
    if (event) {
        [LASharedActivator sendAbortToListener:event];
    }
}

- (void)clearMenuHoldShortEventWithoutAborting {
    LAAssertMainQueue();

    self.menuHoldShortEventToAbort = nil;
}

#pragma mark - Event Dispatch

- (LAEvent *)sendMenuSinglePressEvent {
    LAAssertMainQueue();

    LAEvent *event = [self buttonEventWithName:LAEventNameMenuPressSingle];
    [LASharedActivator sendDeactivateEventToListeners:event];
    if (!event.handled) {
        [LASharedActivator sendEventToListener:event];
    }
    return event;
}

- (LAEvent *)sendButtonEventWithName:(NSString *)eventName {
    LAAssertMainQueue();

    LAEvent *event = [self buttonEventWithName:eventName];
    [LASharedActivator sendEventToListener:event];
    return event;
}

- (LAEvent *)buttonEventWithName:(NSString *)eventName {
    LAAssertMainQueue();

    return [LAEvent eventWithName:eventName mode:[self currentEventMode]];
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

@end
