//
//  LATHardwareHIDEventSender.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "hardware/LATHardwareHIDEventSender.h"

#import "hardware/LATHardwareActionCommand.h"

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

static const uint32_t LATHardwareHIDEventOptionNone = 0;
static const uint64_t LATHardwareHIDSenderID = 0x8000000817319371;
static const NSTimeInterval LATHardwareHIDPressDuration = 0.05;

static uint64_t LATHardwareHIDMachTimeForTimeInterval(NSTimeInterval timeInterval) {
    static mach_timebase_info_data_t sTimebaseInfo;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        mach_timebase_info(&sTimebaseInfo);
    });
    return (uint64_t)(timeInterval * (NSTimeInterval)NSEC_PER_SEC * (NSTimeInterval)sTimebaseInfo.denom /
                      (NSTimeInterval)sTimebaseInfo.numer);
}

@interface LATHardwareHIDEventSender ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) IOHIDEventSystemClientRef client;
@end

@implementation LATHardwareHIDEventSender

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INTERACTIVE, 0);
        _queue = dispatch_queue_create("libactivator.hardware-actions.hid", attr);
    }
    return self;
}

- (BOOL)sendCommand:(LATHardwareActionCommand *)command listenerName:(NSString *)listenerName {
    IOHIDEventSystemClientRef client = [self eventSystemClient];
    if (!client) {
        HBLogError(@"Unable to create IOHID event system client for hardware action %@", listenerName ?: @"");
        return NO;
    }

    uint64_t downTimestamp = mach_absolute_time();
    uint64_t pressDuration = LATHardwareHIDMachTimeForTimeInterval(LATHardwareHIDPressDuration);
    IOHIDEventRef downEvent = [self keyboardEventForCommand:command keyDown:YES timestamp:downTimestamp];
    IOHIDEventRef upEvent = [self keyboardEventForCommand:command keyDown:NO timestamp:downTimestamp + pressDuration];
    if (!downEvent || !upEvent) {
        if (downEvent) {
            CFRelease(downEvent);
        }
        if (upEvent) {
            CFRelease(upEvent);
        }
        HBLogError(@"Unable to create HID keyboard events for hardware action %@", listenerName ?: @"");
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

- (IOHIDEventRef)keyboardEventForCommand:(LATHardwareActionCommand *)command
                                 keyDown:(BOOL)keyDown
                               timestamp:(uint64_t)timestamp {
    IOHIDEventRef event = IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, timestamp, command.page, command.usage,
                                                        keyDown, LATHardwareHIDEventOptionNone);
    if (event) {
        IOHIDEventSetSenderID(event, LATHardwareHIDSenderID);
    }
    return event;
}

@end
