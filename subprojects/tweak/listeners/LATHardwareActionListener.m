//
//  LATHardwareActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATHardwareActionListener.h"

#import <AudioToolbox/AudioToolbox.h>
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

static const uint32_t LATHardwareHIDPageConsumer = 0x0C;
static const uint32_t LATHardwareHIDUsagePower = 0x30;
static const uint32_t LATHardwareHIDUsageMenu = 0x40;
static const uint32_t LATHardwareHIDUsageSnapshot = 0x65;
static const uint32_t LATHardwareHIDUsageDisplayBrightnessIncrement = 0x6F;
static const uint32_t LATHardwareHIDUsageDisplayBrightnessDecrement = 0x70;
static const uint32_t LATHardwareHIDUsagePlay = 0xB0;
static const uint32_t LATHardwareHIDUsagePause = 0xB1;
static const uint32_t LATHardwareHIDUsageScanNextTrack = 0xB5;
static const uint32_t LATHardwareHIDUsageScanPreviousTrack = 0xB6;
static const uint32_t LATHardwareHIDUsagePlayOrPause = 0xCD;
static const uint32_t LATHardwareHIDUsageMute = 0xE2;
static const uint32_t LATHardwareHIDUsageVolumeIncrement = 0xE9;
static const uint32_t LATHardwareHIDUsageVolumeDecrement = 0xEA;
static const uint32_t LATHardwareHIDUsageALKeyboardLayout = 0x1AE;
static const uint32_t LATHardwareHIDUsageACSearch = 0x221;
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

typedef NS_ENUM(NSUInteger, LATHardwareActionKind) {
    LATHardwareActionKindHID,
    LATHardwareActionKindVibrate,
};

@interface LATHardwareActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATHardwareActionKind kind;
@property(nonatomic, assign, readonly) uint32_t page;
@property(nonatomic, assign, readonly) uint32_t usage;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage;
- (instancetype)initWithVibrateListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName;
@end

@interface LATHardwareHIDEventSender : NSObject
- (BOOL)sendCommand:(LATHardwareActionCommand *)command listenerName:(NSString *)listenerName;
@end

@interface LATHardwareVibrator : NSObject
- (BOOL)vibrateForListenerName:(NSString *)listenerName;
@end

@interface LATHardwareHIDEventSender ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) IOHIDEventSystemClientRef client;
@end

@interface LATHardwareActionListener ()
@property(nonatomic, strong) LATHardwareHIDEventSender *sender;
@property(nonatomic, strong) LATHardwareVibrator *vibrator;
@end

@implementation LATHardwareActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATHardwareActionKindHID;
        _page = page;
        _usage = usage;
    }
    return self;
}

- (instancetype)initWithVibrateListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATHardwareActionKindVibrate;
        _page = 0;
        _usage = 0;
    }
    return self;
}

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

@implementation LATHardwareVibrator

- (BOOL)vibrateForListenerName:(NSString *)listenerName {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    return YES;
}

@end

@implementation LATHardwareActionListener

- (instancetype)init {
    self = [super init];
    if (self) {
        _sender = [[LATHardwareHIDEventSender alloc] init];
        _vibrator = [[LATHardwareVibrator alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATHardwareActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
    return command.selectorName;
}

+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator {
    NSString *expectedSelector = [self expectedSelectorForListenerName:listenerName];
    if (listenerName.length == 0 || expectedSelector.length == 0) {
        return NO;
    }

    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:expectedSelector];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    LATHardwareActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Hardware action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Hardware action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    switch (command.kind) {
    case LATHardwareActionKindHID:
        [self.sender sendCommand:command listenerName:listenerName];
        break;
    case LATHardwareActionKindVibrate:
        [self.vibrator vibrateForListenerName:listenerName];
        break;
    }
}

- (BOOL)listenerSelectorMatchesCommand:(LATHardwareActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATHardwareActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATHardwareActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATHardwareActionCommand *> *commandList = @[
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.toggle-playback"
                                                      selectorName:@"togglePlayback"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsagePlayOrPause],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.pause-playback"
                                                      selectorName:@"pauseMedia"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsagePause],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.resume-playback"
                                                      selectorName:@"playMedia"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsagePlay],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.next-track"
                                                      selectorName:@"nextTrack"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageScanNextTrack],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.previous-track"
                                                      selectorName:@"previousTrack"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageScanPreviousTrack],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.increase-volume"
                                                      selectorName:@"increaseVolume"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageVolumeIncrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.decrease-volume"
                                                      selectorName:@"decreaseVolume"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageVolumeDecrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.toggle-output-mute"
                                                      selectorName:@"toggleOutputMute"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageMute],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.screen.brightness.increase"
                                                      selectorName:@"increaseBrightness"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageDisplayBrightnessIncrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.screen.brightness.decrease"
                                                      selectorName:@"decreaseBrightness"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageDisplayBrightnessDecrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.homebutton"
                                                      selectorName:@"homeButton"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageMenu],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.sleepbutton"
                                                      selectorName:@"sleepButtonFromActivator:event:"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsagePower],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.keyboard.toggle-on-screen-keyboard"
                                                      selectorName:@"toggleOnScreenKeyboard"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageALKeyboardLayout],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.take-screenshot"
                                                      selectorName:@"takeScreenshot"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageSnapshot],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.spotlight"
                                                      selectorName:@"spotlight"
                                                              page:LATHardwareHIDPageConsumer
                                                             usage:LATHardwareHIDUsageACSearch],
            [[LATHardwareActionCommand alloc] initWithVibrateListenerName:@"libactivator.system.vibrate"
                                                             selectorName:@"vibrate"],
        ];

        NSMutableDictionary<NSString *, LATHardwareActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATHardwareActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
