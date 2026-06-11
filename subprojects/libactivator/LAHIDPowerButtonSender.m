//
//  LAHIDPowerButtonSender.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAHIDPowerButtonSender.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <mach/mach_time.h>

typedef const struct __IOHIDEvent *IOHIDEventRef;
typedef const struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t usagePage,
                                                   uint32_t usage, Boolean down, uint32_t flags);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

static const uint32_t LAHIDPowerButtonPageConsumer = 0x0C;
static const uint32_t LAHIDPowerButtonUsagePower = 0x30;
static const uint32_t LAHIDPowerButtonEventOptionNone = 0;
static const uint64_t LAHIDPowerButtonSenderID = 0x8000000817319371;
static const NSTimeInterval LAHIDPowerButtonPressDuration = 0.05;

static uint64_t LAHIDPowerButtonMachTimeForTimeInterval(NSTimeInterval timeInterval) {
    static mach_timebase_info_data_t sTimebaseInfo;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        mach_timebase_info(&sTimebaseInfo);
    });
    return (uint64_t)(timeInterval * (NSTimeInterval)NSEC_PER_SEC * (NSTimeInterval)sTimebaseInfo.denom /
                      (NSTimeInterval)sTimebaseInfo.numer);
}

@interface LAHIDPowerButtonSender ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) IOHIDEventSystemClientRef client;
@end

@implementation LAHIDPowerButtonSender

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INTERACTIVE, 0);
        _queue = dispatch_queue_create("libactivator.power-button.hid", attr);
    }
    return self;
}

- (BOOL)sendPowerButtonPressForReason:(NSString *)reason {
    IOHIDEventSystemClientRef client = [self eventSystemClient];
    if (!client) {
        HBLogError(@"Unable to create IOHID event system client for power button press: %@", reason ?: @"");
        return NO;
    }

    uint64_t downTimestamp = mach_absolute_time();
    uint64_t pressDuration = LAHIDPowerButtonMachTimeForTimeInterval(LAHIDPowerButtonPressDuration);
    IOHIDEventRef downEvent = [self powerButtonEventWithKeyDown:YES timestamp:downTimestamp];
    IOHIDEventRef upEvent = [self powerButtonEventWithKeyDown:NO timestamp:downTimestamp + pressDuration];
    if (!downEvent || !upEvent) {
        if (downEvent) {
            CFRelease(downEvent);
        }
        if (upEvent) {
            CFRelease(upEvent);
        }
        HBLogError(@"Unable to create HID events for power button press: %@", reason ?: @"");
        return NO;
    }

    dispatch_async(self.queue, ^{
        IOHIDEventSystemClientDispatchEvent(client, downEvent);
        IOHIDEventSystemClientDispatchEvent(client, upEvent);
        CFRelease(downEvent);
        CFRelease(upEvent);
    });
    return YES;
}

- (IOHIDEventSystemClientRef)eventSystemClient {
    if (!self.client) {
        self.client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
    return self.client;
}

- (IOHIDEventRef)powerButtonEventWithKeyDown:(BOOL)keyDown timestamp:(uint64_t)timestamp {
    IOHIDEventRef event =
        IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, timestamp, LAHIDPowerButtonPageConsumer,
                                      LAHIDPowerButtonUsagePower, keyDown, LAHIDPowerButtonEventOptionNone);
    if (event) {
        IOHIDEventSetSenderID(event, LAHIDPowerButtonSenderID);
    }
    return event;
}

@end
