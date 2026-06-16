//
//  LATHIDEventSender.m
//  ActivatorTweak
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATHIDEventSender.h"

#import "IOKitSPI.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <mach/mach_time.h>
#import <os/lock.h>

static const uint64_t LATHIDEventSenderID = 0x8000000817319371;
static const NSTimeInterval LATHIDEventPressDuration = 0.05;

@interface LATHIDEventSender () {
    os_unfair_lock _clientLock;
}

// Dispatch queue
@property(nonatomic, strong) dispatch_queue_t queue;

// Lazily initialized CoreFoundation client
@property(nonatomic, assign, nullable) IOHIDEventSystemClientRef client;

@end

@implementation LATHIDEventSender

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INTERACTIVE, 0);
        _queue = dispatch_queue_create("libactivator.tweak.hid-events", attr);
        _clientLock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

- (void)dealloc {
    if (_client) {
        CFRelease(_client);
        _client = NULL;
    }
}

- (BOOL)sendKeyboardUsagePage:(uint32_t)usagePage usage:(uint32_t)usage reason:(NSString *)reason {
    IOHIDEventSystemClientRef client = [self eventSystemClient];
    if (!client) {
        HBLogError(@"Unable to create IOHID event system client for HID action %@", reason ?: @"");
        return NO;
    }

    uint64_t downTimestamp = mach_absolute_time();
    uint64_t pressDuration = [self machTimeForTimeInterval:LATHIDEventPressDuration];
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

    CFRetain(client);
    dispatch_async(self.queue, ^{
        IOHIDEventSystemClientDispatchEvent(client, downEvent);
        IOHIDEventSystemClientDispatchEvent(client, upEvent);
        CFRelease(client);
        CFRelease(downEvent);
        CFRelease(upEvent);
    });
    return YES;
}

- (IOHIDEventSystemClientRef)eventSystemClient {
    os_unfair_lock_lock(&_clientLock);
    IOHIDEventSystemClientRef client = _client;
    if (!client) {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        _client = client;
    }
    os_unfair_lock_unlock(&_clientLock);
    return client;
}

- (IOHIDEventRef)keyboardEventWithUsagePage:(uint32_t)usagePage
                                      usage:(uint32_t)usage
                                    keyDown:(BOOL)keyDown
                                  timestamp:(uint64_t)timestamp {
    IOHIDEventRef event =
        IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, timestamp, usagePage, usage, keyDown, kIOHIDEventOptionNone);
    if (event) {
        IOHIDEventSetSenderID(event, LATHIDEventSenderID);
    }
    return event;
}

- (uint64_t)machTimeForTimeInterval:(NSTimeInterval)timeInterval {
    static mach_timebase_info_data_t sTimebaseInfo;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        mach_timebase_info(&sTimebaseInfo);
    });
    return (uint64_t)(timeInterval * (NSTimeInterval)NSEC_PER_SEC * (NSTimeInterval)sTimebaseInfo.denom /
                      (NSTimeInterval)sTimebaseInfo.numer);
}

@end
