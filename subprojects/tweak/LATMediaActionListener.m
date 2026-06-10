//
//  LATMediaActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMediaActionListener.h"

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

static const uint32_t LATMediaHIDPageConsumer = 0x0C;
static const uint32_t LATMediaHIDUsagePlay = 0xB0;
static const uint32_t LATMediaHIDUsagePause = 0xB1;
static const uint32_t LATMediaHIDUsageScanNextTrack = 0xB5;
static const uint32_t LATMediaHIDUsageScanPreviousTrack = 0xB6;
static const uint32_t LATMediaHIDUsagePlayOrPause = 0xCD;
static const uint32_t LATMediaHIDUsageVolumeIncrement = 0xE9;
static const uint32_t LATMediaHIDUsageVolumeDecrement = 0xEA;
static const uint32_t LATMediaHIDEventOptionNone = 0;
static const uint64_t LATMediaHIDSenderID = 0x8000000817319371;

typedef NS_ENUM(NSUInteger, LATMediaActionKind) {
    LATMediaActionKindHID,
    LATMediaActionKindVolumeHUD,
};

@interface LATMediaActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATMediaActionKind kind;
@property(nonatomic, assign, readonly) uint32_t page;
@property(nonatomic, assign, readonly) uint32_t usage;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage;
- (instancetype)initWithVolumeHUDListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName;
@end

@interface LATMediaHIDEventSender : NSObject
- (BOOL)sendCommand:(LATMediaActionCommand *)command listenerName:(NSString *)listenerName;
@end

@interface LATMediaVolumeHUDPresenter : NSObject
- (BOOL)presentVolumeHUDForListenerName:(NSString *)listenerName;
@end

@interface LATMediaActionListener ()
+ (id)volumeControlInstance;
@end

static __weak id LATCapturedVolumeControl = nil;

#if LA_TESTING
static LATMediaActionSendHandler LATTestingSendHandler = nil;
static NSString *LATTestingLastSentListenerName = nil;
static uint32_t LATTestingLastSentPage = 0;
static uint32_t LATTestingLastSentUsage = 0;
static NSMutableArray<NSString *> *LATTestingSentPhases = nil;
static NSMutableDictionary<NSString *, NSString *> *LATTestingSelectors = nil;
#endif

@implementation LATMediaActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATMediaActionKindHID;
        _page = page;
        _usage = usage;
    }
    return self;
}

- (instancetype)initWithVolumeHUDListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATMediaActionKindVolumeHUD;
        _page = 0;
        _usage = 0;
    }
    return self;
}

@end

@implementation LATMediaHIDEventSender {
    dispatch_queue_t _queue;
    IOHIDEventSystemClientRef _client;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INTERACTIVE, 0);
        _queue = dispatch_queue_create("com.libactivator.media-actions.hid", attr);
    }
    return self;
}

- (BOOL)sendCommand:(LATMediaActionCommand *)command listenerName:(NSString *)listenerName {
#if LA_TESTING
    LATTestingLastSentListenerName = [listenerName copy];
    LATTestingLastSentPage = command.page;
    LATTestingLastSentUsage = command.usage;
    if (!LATTestingSentPhases) {
        LATTestingSentPhases = [[NSMutableArray alloc] init];
    }
    [LATTestingSentPhases addObject:@"down"];
    [LATTestingSentPhases addObject:@"up"];
    if (LATTestingSendHandler) {
        return LATTestingSendHandler(listenerName ?: @"", command.page, command.usage);
    }
#endif

    IOHIDEventSystemClientRef client = [self eventSystemClient];
    if (!client) {
        HBLogError(@"Unable to create IOHID event system client for media action %@", listenerName ?: @"");
        return NO;
    }

    IOHIDEventRef downEvent = [self keyboardEventForCommand:command keyDown:YES];
    IOHIDEventRef upEvent = [self keyboardEventForCommand:command keyDown:NO];
    if (!downEvent || !upEvent) {
        if (downEvent) {
            CFRelease(downEvent);
        }
        if (upEvent) {
            CFRelease(upEvent);
        }
        HBLogError(@"Unable to create HID keyboard events for media action %@", listenerName ?: @"");
        return NO;
    }

    dispatch_async(_queue, ^{
        IOHIDEventSystemClientDispatchEvent(client, downEvent);
        IOHIDEventSystemClientDispatchEvent(client, upEvent);
        CFRelease(downEvent);
        CFRelease(upEvent);
    });
    return YES;
}

- (IOHIDEventSystemClientRef)eventSystemClient {
    if (!_client) {
        _client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
    return _client;
}

- (IOHIDEventRef)keyboardEventForCommand:(LATMediaActionCommand *)command keyDown:(BOOL)keyDown {
    IOHIDEventRef event = IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), command.page,
                                                        command.usage, keyDown, LATMediaHIDEventOptionNone);
    if (event) {
        IOHIDEventSetSenderID(event, LATMediaHIDSenderID);
    }
    return event;
}

@end

@implementation LATMediaVolumeHUDPresenter

- (BOOL)presentVolumeHUDForListenerName:(NSString *)listenerName {
#if LA_TESTING
    LATTestingLastSentListenerName = [listenerName copy];
    LATTestingLastSentPage = 0;
    LATTestingLastSentUsage = 0;
    if (!LATTestingSentPhases) {
        LATTestingSentPhases = [[NSMutableArray alloc] init];
    }
    [LATTestingSentPhases addObject:@"volume-hud"];
    if (LATTestingSendHandler) {
        return LATTestingSendHandler(listenerName ?: @"", 0, 0);
    }
#endif

    if (![NSThread isMainThread]) {
        __block BOOL presented = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            presented = [self presentVolumeHUDForListenerName:listenerName];
        });
        return presented;
    }

    id volumeControl = [LATMediaActionListener volumeControlInstance];
    if (!volumeControl) {
        HBLogError(@"Unable to present volume HUD for media action %@ because SBVolumeControl was not captured",
                   listenerName ?: @"");
        return NO;
    }

    SEL presentSelector = NSSelectorFromString(@"_presentVolumeHUDWithVolume:");
    if (![volumeControl respondsToSelector:presentSelector]) {
        HBLogError(@"SBVolumeControl does not support _presentVolumeHUDWithVolume:");
        return NO;
    }

    float volume = 0.5f;
    SEL effectiveVolumeSelector = NSSelectorFromString(@"_effectiveVolume");
    if ([volumeControl respondsToSelector:effectiveVolumeSelector]) {
        float (*effectiveVolume)(id, SEL) =
            (float (*)(id, SEL))[volumeControl methodForSelector:effectiveVolumeSelector];
        volume = effectiveVolume(volumeControl, effectiveVolumeSelector);
    }

    void (*presentVolumeHUD)(id, SEL, float) =
        (void (*)(id, SEL, float))[volumeControl methodForSelector:presentSelector];
    presentVolumeHUD(volumeControl, presentSelector, volume);
    return YES;
}

@end

@implementation LATMediaActionListener {
    LATMediaHIDEventSender *_sender;
    LATMediaVolumeHUDPresenter *_volumeHUDPresenter;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sender = [[LATMediaHIDEventSender alloc] init];
        _volumeHUDPresenter = [[LATMediaVolumeHUDPresenter alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATMediaActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATMediaActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Media action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Media action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    BOOL sent = NO;
    switch (command.kind) {
    case LATMediaActionKindHID:
        sent = [_sender sendCommand:command listenerName:listenerName];
        break;
    case LATMediaActionKindVolumeHUD:
        sent = [_volumeHUDPresenter presentVolumeHUDForListenerName:listenerName];
        break;
    }
    if (sent) {
        event.handled = YES;
    }
}

- (BOOL)listenerSelectorMatchesCommand:(LATMediaActionCommand *)command activator:(LAActivator *)activator {
#if LA_TESTING
    NSString *testingSelector = LATTestingSelectors[command.listenerName];
    if (testingSelector) {
        return [testingSelector isEqualToString:command.selectorName];
    }
#endif

    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATMediaActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATMediaActionCommand *> *commands;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<LATMediaActionCommand *> *commandList = @[
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.ipod.toggle-playback"
                                                   selectorName:@"togglePlayback"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsagePlayOrPause],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.ipod.pause-playback"
                                                   selectorName:@"pauseMedia"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsagePause],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.ipod.resume-playback"
                                                   selectorName:@"playMedia"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsagePlay],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.ipod.next-track"
                                                   selectorName:@"nextTrack"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsageScanNextTrack],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.ipod.previous-track"
                                                   selectorName:@"previousTrack"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsageScanPreviousTrack],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.audio.increase-volume"
                                                   selectorName:@"increaseVolume"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsageVolumeIncrement],
            [[LATMediaActionCommand alloc] initWithListenerName:@"libactivator.audio.decrease-volume"
                                                   selectorName:@"decreaseVolume"
                                                           page:LATMediaHIDPageConsumer
                                                          usage:LATMediaHIDUsageVolumeDecrement],
            [[LATMediaActionCommand alloc] initWithVolumeHUDListenerName:@"libactivator.audio.show-volume-bar"
                                                            selectorName:@"showVolumeBar"],
        ];

        NSMutableDictionary<NSString *, LATMediaActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATMediaActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        commands = [mutableCommands copy];
    });
    return commands;
}

+ (void)noteVolumeControlInstance:(id)volumeControl {
    if (volumeControl) {
        LATCapturedVolumeControl = volumeControl;
    }
}

+ (id)volumeControlInstance {
    return LATCapturedVolumeControl;
}

#if LA_TESTING
+ (void)setTestingSendHandler:(LATMediaActionSendHandler)handler {
    LATTestingSendHandler = [handler copy];
}

+ (void)setTestingSelector:(NSString *)selector forListenerName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return;
    }
    if (!LATTestingSelectors) {
        LATTestingSelectors = [[NSMutableDictionary alloc] init];
    }
    if (selector) {
        LATTestingSelectors[listenerName] = selector;
    } else {
        [LATTestingSelectors removeObjectForKey:listenerName];
    }
}

+ (NSString *)testingLastSentListenerName {
    return LATTestingLastSentListenerName;
}

+ (uint32_t)testingLastSentPage {
    return LATTestingLastSentPage;
}

+ (uint32_t)testingLastSentUsage {
    return LATTestingLastSentUsage;
}

+ (NSArray<NSString *> *)testingSentPhases {
    return [LATTestingSentPhases copy] ?: @[];
}

+ (void)resetTestingState {
    LATTestingSendHandler = nil;
    LATTestingLastSentListenerName = nil;
    LATTestingLastSentPage = 0;
    LATTestingLastSentUsage = 0;
    [LATTestingSentPhases removeAllObjects];
    [LATTestingSelectors removeAllObjects];
}
#endif

@end
