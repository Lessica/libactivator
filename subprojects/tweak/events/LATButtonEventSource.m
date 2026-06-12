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
    kLATHIDPageConsumer = 0x0C,
};

enum {
    kLATHIDUsageConsumerMenu = 0x40,
    kLATHIDUsageConsumerVolumeIncrement = 0xE9,
    kLATHIDUsageConsumerVolumeDecrement = 0xEA,
};

extern IOHIDEventType IOHIDEventGetType(IOHIDEventRef event);
extern CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef event, IOHIDEventField field);

@interface LATButtonEventSource ()
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign, getter=isMenuButtonDown) BOOL menuButtonDown;
@property(nonatomic, assign, getter=isVolumeUpButtonDown) BOOL volumeUpButtonDown;
@property(nonatomic, assign, getter=isVolumeDownButtonDown) BOOL volumeDownButtonDown;
@property(nonatomic, assign, getter=isVolumeChordConsumed) BOOL volumeChordConsumed;
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

    if (IOHIDEventGetType(event) != kLATIOHIDEventTypeKeyboard) {
        return;
    }

    CFIndex usagePage = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardUsagePage);
    if (usagePage != kLATHIDPageConsumer) {
        return;
    }

    CFIndex usage = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardUsage);
    BOOL keyDown = IOHIDEventGetIntegerValue(event, kLATIOHIDEventFieldKeyboardDown) != 0;
    [self handleConsumerKeyboardUsage:usage keyDown:keyDown];
}

- (void)handleConsumerKeyboardUsage:(CFIndex)usage keyDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    switch (usage) {
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

- (void)handleVolumeUpButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (keyDown) {
        if (self.volumeUpButtonDown) {
            return;
        }
        self.volumeUpButtonDown = YES;
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeUpPressWithMenu];
        [self sendVolumeBothPressIfNeeded];
        return;
    }

    if (!self.volumeUpButtonDown) {
        [self resetVolumeChordConsumedIfNoButtonsAreDown];
        return;
    }
    self.volumeUpButtonDown = NO;
    if (self.volumeChordConsumed) {
        [self resetVolumeChordConsumedIfNoButtonsAreDown];
        return;
    }
    [self sendButtonEventWithName:LAEventNameVolumeUpPress];
}

- (void)handleVolumeDownButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (keyDown) {
        if (self.volumeDownButtonDown) {
            return;
        }
        self.volumeDownButtonDown = YES;
        [self sendVolumeMenuPressIfNeededWithEventName:LAEventNameVolumeDownPressWithMenu];
        [self sendVolumeBothPressIfNeeded];
        return;
    }

    if (!self.volumeDownButtonDown) {
        [self resetVolumeChordConsumedIfNoButtonsAreDown];
        return;
    }
    self.volumeDownButtonDown = NO;
    if (self.volumeChordConsumed) {
        [self resetVolumeChordConsumedIfNoButtonsAreDown];
        return;
    }
    [self sendButtonEventWithName:LAEventNameVolumeDownPress];
}

- (void)handleMenuButtonDown:(BOOL)keyDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (keyDown) {
        if (self.menuButtonDown) {
            return;
        }
        self.menuButtonDown = YES;
        [self sendVolumeMenuPressForCurrentVolumeButtonIfNeeded];
        return;
    }

    if (!self.menuButtonDown) {
        [self resetVolumeChordConsumedIfNoButtonsAreDown];
        return;
    }
    self.menuButtonDown = NO;
    [self resetVolumeChordConsumedIfNoButtonsAreDown];
}

- (void)sendVolumeBothPressIfNeeded {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (self.volumeChordConsumed || !self.volumeUpButtonDown || !self.volumeDownButtonDown) {
        return;
    }

    self.volumeChordConsumed = YES;
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

    if (self.volumeChordConsumed || !self.menuButtonDown || (!self.volumeUpButtonDown && !self.volumeDownButtonDown)) {
        return;
    }

    self.volumeChordConsumed = YES;
    [self sendButtonEventWithName:eventName];
}

- (void)resetVolumeChordConsumedIfNoButtonsAreDown {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    if (!self.menuButtonDown && !self.volumeUpButtonDown && !self.volumeDownButtonDown) {
        self.volumeChordConsumed = NO;
    }
}

#pragma mark - Event Dispatch

- (void)sendButtonEventWithName:(NSString *)eventName {
    NSAssert(NSThread.isMainThread, kLATButtonEventSourceMainQueueReason);

    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
