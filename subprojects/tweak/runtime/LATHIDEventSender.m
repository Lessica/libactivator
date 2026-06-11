//
//  LATHIDEventSender.m
//  ActivatorTweak
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATHIDEventSender.h"

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

static const uint32_t LATHIDEventOptionNone = 0;
static const uint64_t LATHIDEventSenderID = 0x8000000817319371;
static const NSTimeInterval LATHIDEventPressDuration = 0.05;

static uint64_t LATHIDMachTimeForTimeInterval(NSTimeInterval timeInterval) {
    static mach_timebase_info_data_t sTimebaseInfo;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        mach_timebase_info(&sTimebaseInfo);
    });
    return (uint64_t)(timeInterval * (NSTimeInterval)NSEC_PER_SEC * (NSTimeInterval)sTimebaseInfo.denom /
                      (NSTimeInterval)sTimebaseInfo.numer);
}

@interface LATHIDEventSender ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) IOHIDEventSystemClientRef client;
@end

@implementation LATHIDEventSender

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INTERACTIVE, 0);
        _queue = dispatch_queue_create("libactivator.tweak.hid-events", attr);
    }
    return self;
}

- (BOOL)sendKeyboardUsagePage:(uint32_t)usagePage usage:(uint32_t)usage reason:(NSString *)reason {
    IOHIDEventSystemClientRef client = [self eventSystemClient];
    if (!client) {
        HBLogError(@"Unable to create IOHID event system client for HID action %@", reason ?: @"");
        return NO;
    }

    uint64_t downTimestamp = mach_absolute_time();
    uint64_t pressDuration = LATHIDMachTimeForTimeInterval(LATHIDEventPressDuration);
    IOHIDEventRef downEvent = [self keyboardEventWithUsagePage:usagePage
                                                         usage:usage
                                                       keyDown:YES
                                                     timestamp:downTimestamp];
    IOHIDEventRef upEvent = [self keyboardEventWithUsagePage:usagePage
                                                       usage:usage
                                                     keyDown:NO
                                                   timestamp:downTimestamp + pressDuration];
    if (!downEvent || !upEvent) {
        if (downEvent) {
            CFRelease(downEvent);
        }
        if (upEvent) {
            CFRelease(upEvent);
        }
        HBLogError(@"Unable to create HID keyboard events for HID action %@", reason ?: @"");
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

- (IOHIDEventRef)keyboardEventWithUsagePage:(uint32_t)usagePage
                                      usage:(uint32_t)usage
                                    keyDown:(BOOL)keyDown
                                  timestamp:(uint64_t)timestamp {
    IOHIDEventRef event =
        IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, timestamp, usagePage, usage, keyDown, LATHIDEventOptionNone);
    if (event) {
        IOHIDEventSetSenderID(event, LATHIDEventSenderID);
    }
    return event;
}

@end
