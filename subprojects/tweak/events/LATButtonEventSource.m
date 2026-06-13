//
//  LATButtonEventSource.m
//  libactivator
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATButtonEventSource.h"

#import "LAActivator+Private.h"

#define kLATButtonEventSourceMainQueueReason @"LATButtonEventSource must only be used on the main thread"

static NSTimeInterval const LATButtonEventSourceHoldDelay = 0.45;
static NSTimeInterval const LATButtonEventSourceMenuLongHoldDelay = 2.5;
static NSTimeInterval const LATButtonEventSourceLockLongHoldDelay = 2.5;
static NSTimeInterval const LATButtonEventSourceRingerToggleTwiceDelay = 1.0;
static NSString *const LATLockPressTripleEventName = @"libactivator.lock.press.triple";

typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventType;

#define LATIOHIDEventFieldBase(type) ((type) << 16)

enum {
    kLATIOHIDEventTypeKeyboard = 3,
};

enum {
    kLATIOHIDEventFieldKeyboardUsagePage = LATIOHIDEventFieldBase(kLATIOHIDEventTypeKeyboard),
    kLATIOHIDEventFieldKeyboardUsage,
    kLATIOHIDEventFieldKeyboardDown,
};

enum {
    kLATHIDPageTelephony = 0x0B,
    kLATHIDPageConsumer = 0x0C,
};

enum {
    kLATHIDUsageTelephonyMute = 0x2E,
};

enum {
    kLATHIDUsageConsumerPower = 0x30,
    kLATHIDUsageConsumerMenu = 0x40,
    kLATHIDUsageConsumerVolumeIncrement = 0xE9,
    kLATHIDUsageConsumerVolumeDecrement = 0xEA,
};

extern IOHIDEventType IOHIDEventGetType(IOHIDEventRef event);
extern CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef event, IOHIDEventField field);
extern uint64_t IOHIDEventGetSenderID(IOHIDEventRef event);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);
    if (self.started) {
        return;
    }
    self.started = YES;
}

#pragma mark - HID Events

- (void)noteHIDEvent:(IOHIDEventRef)event {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);
    if (!self.started || !event) {
        return;
    }

    if ((IOHIDEventGetSenderID(event) & LATButtonEventSourceSyntheticSenderIDMask) != 0) {
        return;
    }

    if (IOHIDEventGetType(event) != kLATIOHIDEventTypeKeyboard) {
        return;
    }

    CFIndex usagePage = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardUsagePage);
    CFIndex usage = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardUsage);
    BOOL keyDown = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardDown) != 0;
    if (usagePage == kLATHIDPageTelephony && usage == kLATHIDUsageTelephonyMute) {
        [self handleRingerSwitchIsUnmuted:keyDown];
        return;
    }

    if (usagePage != kLATHIDPageConsumer) {
        return;
    }

    [self handleConsumerKeyboardUsage:usage keyDown:keyDown];
}

- (void)handleConsumerKeyboardUsage:(CFIndex)usage keyDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    switch (usage) {
    case kLATHIDUsageConsumerPower:
        [self handleLockButtonDown:keyDown];
        break;
    case kLATHIDUsageConsumerMenu:
        [self handleMenuButtonDown:keyDown];
        break;
    case kLATHIDUsageConsumerVolumeIncrement:
        [self handleVolumeUpButtonDown:keyDown];
        break;
    case kLATHIDUsageConsumerVolumeDecrement:
        [self handleVolumeDownButtonDown:keyDown];
        break;
    default:
        break;
    }
}

- (void)handleLockButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    [self sendVolumePressOrSequenceWithPressEventName:LAEventNameVolumeUpPress
                                                usage:kLATHIDUsageConsumerVolumeIncrement];
}

- (void)handleVolumeDownButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    [self sendVolumePressOrSequenceWithPressEventName:LAEventNameVolumeDownPress
                                                usage:kLATHIDUsageConsumerVolumeDecrement];
}

- (void)handleMenuButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (self.buttonSequenceConsumed || !self.lockButtonDown || !self.menuButtonDown) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:LAEventNameLockPressWithMenu];
}

- (void)sendVolumeBothPressIfNeeded {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (self.buttonSequenceConsumed || !self.volumeUpButtonDown || !self.volumeDownButtonDown) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:LAEventNameVolumeBothPress];
}

- (void)sendVolumeMenuPressForCurrentVolumeButtonIfNeeded {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (self.volumeUpButtonDown && !self.volumeDownButtonDown) {
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeUpPressWithMenu];
    } else if (self.volumeDownButtonDown && !self.volumeUpButtonDown) {
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeDownPressWithMenu];
    }
}

- (void)sendVolumeMenuPressIfNeededWithEventName:(NSString *)eventName {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (self.buttonSequenceConsumed || !self.menuButtonDown ||
        (!self.volumeUpButtonDown && !self.volumeDownButtonDown)) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:eventName];
}

- (void)resetButtonSequenceConsumedIfNoButtonsAreDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (!self.lockButtonDown && !self.menuButtonDown && !self.volumeUpButtonDown && !self.volumeDownButtonDown) {
        self.buttonSequenceConsumed = NO;
    }
}

#pragma mark - Lock Press Recognition

- (void)noteLockPressRelease {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
        if ([self hasAssignedListenerForEventName:LATLockPressTripleEventName]) {
            [self scheduleLockPressResolutionForPressCount:2];
        } else {
            [self cancelLockPressRecognition];
            [self sendButtonEventWithName:LAEventNameLockPressDouble];
        }
        return;
    }

    [self cancelLockPressRecognition];
    [self sendButtonEventWithName:LATLockPressTripleEventName];
}

- (void)scheduleLockPressResolutionForPressCount:(NSUInteger)pressCount {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    return [self hasAssignedListenerForEventName:LAEventNameLockPressDouble] ||
           [self hasAssignedListenerForEventName:LATLockPressTripleEventName];
}

- (void)cancelLockPressRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.lockPressGeneration += 1;
    self.lockPressCount = 0;
}

#pragma mark - Menu Press Recognition

- (void)noteMenuPressRelease {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    return [self hasAssignedListenerForEventName:LAEventNameMenuPressDouble] ||
           [self hasAssignedListenerForEventName:LAEventNameMenuPressTriple];
}

- (BOOL)hasAssignedListenerForEventName:(NSString *)eventName {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    NSString *eventMode = [self currentEventMode];
    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    return [LASharedActivator listenerForEvent:event] != nil;
}

- (void)cancelMenuPressRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.menuPressGeneration += 1;
    self.menuPressCount = 0;
}

#pragma mark - Volume Sequence Recognition

- (void)sendVolumePressOrSequenceWithPressEventName:(NSString *)pressEventName usage:(CFIndex)usage {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - self.lastVolumePressTime > LATButtonEventSourceHoldDelay) {
        self.lastVolumePressUsage = usage;
        self.lastVolumePressTime = currentTime;
        [self sendButtonEventWithName:pressEventName];
        return;
    }

    NSString *sequenceEventName = nil;
    if (self.lastVolumePressUsage == kLATHIDUsageConsumerVolumeIncrement &&
        usage == kLATHIDUsageConsumerVolumeDecrement) {
        sequenceEventName = LAEventNameVolumeUpDown;
    } else if (self.lastVolumePressUsage == kLATHIDUsageConsumerVolumeDecrement &&
               usage == kLATHIDUsageConsumerVolumeIncrement) {
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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);
    self.volumeUpHoldGeneration += 1;
}

- (void)cancelVolumeDownHoldRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);
    self.volumeDownHoldGeneration += 1;
}

- (void)cancelVolumeHoldRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);
    [self cancelVolumeUpHoldRecognition];
    [self cancelVolumeDownHoldRecognition];
}

- (void)scheduleLockHoldRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.lockHoldGeneration += 1;
    self.lockShortHoldRecognized = NO;
}

- (void)scheduleMenuHoldRecognition {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.menuHoldGeneration += 1;
    self.menuShortHoldRecognized = NO;
}

- (void)sendVolumeHoldEventIfNeededWithName:(NSString *)eventName
                                  keyIsDown:(BOOL)keyIsDown
                                 generation:(NSUInteger)generation
                          currentGeneration:(NSUInteger)currentGeneration {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (generation != currentGeneration || !keyIsDown || self.buttonSequenceConsumed) {
        return;
    }

    [self consumeButtonSequence];
    [self sendButtonEventWithName:eventName];
}

- (void)consumeButtonSequence {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    LAEvent *event = self.lockHoldShortEventToAbort;
    self.lockHoldShortEventToAbort = nil;
    if (event) {
        [LASharedActivator sendAbortToListener:event];
    }
}

- (void)clearLockHoldShortEventWithoutAborting {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.lockHoldShortEventToAbort = nil;
}

- (void)sendMenuShortHoldEventIfNeededWithGeneration:(NSUInteger)generation {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    LAEvent *event = self.menuHoldShortEventToAbort;
    self.menuHoldShortEventToAbort = nil;
    if (event) {
        [LASharedActivator sendAbortToListener:event];
    }
}

- (void)clearMenuHoldShortEventWithoutAborting {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    self.menuHoldShortEventToAbort = nil;
}

#pragma mark - Event Dispatch

- (LAEvent *)sendMenuSinglePressEvent {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    LAEvent *event = [self buttonEventWithName:LAEventNameMenuPressSingle];
    [LASharedActivator sendDeactivateEventToListeners:event];
    if (!event.handled) {
        [LASharedActivator sendEventToListener:event];
    }
    return event;
}

- (LAEvent *)sendButtonEventWithName:(NSString *)eventName {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    LAEvent *event = [self buttonEventWithName:eventName];
    [LASharedActivator sendEventToListener:event];
    return event;
}

- (LAEvent *)buttonEventWithName:(NSString *)eventName {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    return [LAEvent eventWithName:eventName mode:[self currentEventMode]];
}

- (NSString *)currentEventMode {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    NSString *eventMode = LASharedActivator.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

@end
