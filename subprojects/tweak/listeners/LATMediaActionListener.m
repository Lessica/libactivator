//
//  LATMediaActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMediaActionListener.h"

#import "LATBuiltInListenerRegistry.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <sys/types.h>

@interface SpringBoard : UIApplication
+ (instancetype)sharedApplication;
- (void)launchApplicationWithIdentifier:(NSString *)displayIdentifier suspended:(BOOL)suspended;
@end

@interface SBVolumeControl : NSObject
- (float)_effectiveVolume;
- (void)_presentVolumeHUDWithVolume:(float)volume;
@end

typedef const struct __IOHIDEvent *IOHIDEventRef;
typedef const struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t usagePage,
                                                   uint32_t usage, Boolean down, uint32_t flags);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

extern void MRMediaRemoteSetWantsNowPlayingNotifications(Boolean wantsNotifications) __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t queue,
                                                           void (^completion)(CFStringRef displayID))
    __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationPID(dispatch_queue_t queue, void (^completion)(int PID))
    __attribute__((weak_import));
extern CFStringRef SBSCopyDisplayIdentifierForProcessID(pid_t PID) __attribute__((weak_import));

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
    LATMediaActionKindNowPlayingApplication,
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
- (instancetype)initWithNowPlayingApplicationListenerName:(NSString *)listenerName;
- (BOOL)requiresSelectorMetadata;
@end

@interface LATMediaHIDEventSender : NSObject
- (BOOL)sendCommand:(LATMediaActionCommand *)command listenerName:(NSString *)listenerName;
@end

@interface LATMediaVolumeHUDPresenter : NSObject
- (BOOL)presentVolumeHUDForListenerName:(NSString *)listenerName;
@end

@interface LATMediaNowPlayingApplicationLauncher : NSObject
- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName;
@end

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

- (instancetype)initWithNowPlayingApplicationListenerName:(NSString *)listenerName {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = nil;
        _kind = LATMediaActionKindNowPlayingApplication;
        _page = 0;
        _usage = 0;
    }
    return self;
}

- (BOOL)requiresSelectorMetadata {
    return _selectorName.length > 0;
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
    if (![NSThread isMainThread]) {
        __block BOOL presented = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            presented = [self presentVolumeHUDForListenerName:listenerName];
        });
        return presented;
    }

    SBVolumeControl *volumeControl = LATBuiltInListenerRegistry.volumeControlInstance;
    if (!volumeControl) {
        HBLogError(@"Unable to present volume HUD for media action %@ because SBVolumeControl was not captured",
                   listenerName ?: @"");
        return NO;
    }

    if (![volumeControl respondsToSelector:@selector(_presentVolumeHUDWithVolume:)]) {
        HBLogError(@"SBVolumeControl does not support _presentVolumeHUDWithVolume:");
        return NO;
    }

    float volume = 0.5f;
    if ([volumeControl respondsToSelector:@selector(_effectiveVolume)]) {
        volume = [volumeControl _effectiveVolume];
    }

    [volumeControl _presentVolumeHUDWithVolume:volume];
    return YES;
}

@end

@implementation LATMediaNowPlayingApplicationLauncher {
    dispatch_queue_t _queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0);
        _queue = dispatch_queue_create("com.libactivator.media-actions.now-playing-launch", attr);
    }
    return self;
}

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName {
    if (MRMediaRemoteSetWantsNowPlayingNotifications) {
        MRMediaRemoteSetWantsNowPlayingNotifications(true);
    }

    if (MRMediaRemoteGetNowPlayingApplicationDisplayID) {
        [self requestNowPlayingApplicationDisplayIdentifierForListenerName:listenerName ?: @""];
        return YES;
    }

    if (MRMediaRemoteGetNowPlayingApplicationPID && SBSCopyDisplayIdentifierForProcessID) {
        [self requestNowPlayingApplicationProcessIdentifierForListenerName:listenerName ?: @""];
        return YES;
    }

    HBLogError(@"Unable to launch now-playing application for media action %@ because MediaRemote identity APIs are "
               @"unavailable",
               listenerName ?: @"");
    return NO;
}

- (void)requestNowPlayingApplicationDisplayIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationDisplayID(_queue, ^(CFStringRef displayID) {
        NSString *identifier = [(__bridge NSString *)displayID copy];
        if (identifier.length > 0) {
            [self launchApplicationWithIdentifier:identifier listenerName:listenerName];
            return;
        }

        HBLogWarn(@"MediaRemote returned no now-playing application display identifier for media action %@",
                  listenerName ?: @"");
        if (MRMediaRemoteGetNowPlayingApplicationPID && SBSCopyDisplayIdentifierForProcessID) {
            [self requestNowPlayingApplicationProcessIdentifierForListenerName:listenerName];
        }
    });
}

- (void)requestNowPlayingApplicationProcessIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationPID(_queue, ^(int PID) {
        if (PID <= 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application process identifier for media action %@",
                      listenerName ?: @"");
            return;
        }

        CFStringRef displayID = SBSCopyDisplayIdentifierForProcessID((pid_t)PID);
        NSString *identifier = displayID ? CFBridgingRelease(displayID) : nil;
        if (identifier.length == 0) {
            HBLogError(@"Unable to resolve now-playing application display identifier for process %d", PID);
            return;
        }

        [self launchApplicationWithIdentifier:identifier listenerName:listenerName];
    });
}

- (void)launchApplicationWithIdentifier:(NSString *)displayIdentifier listenerName:(NSString *)listenerName {
    if (displayIdentifier.length == 0) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self launchApplicationWithIdentifier:displayIdentifier]) {
            HBLogError(@"Unable to launch now-playing application %@ for media action %@", displayIdentifier,
                       listenerName ?: @"");
        }
    });
}

- (BOOL)launchApplicationWithIdentifier:(NSString *)displayIdentifier {
    if (![NSThread isMainThread]) {
        __block BOOL launched = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            launched = [self launchApplicationWithIdentifier:displayIdentifier];
        });
        return launched;
    }

    Class springBoardClass = NSClassFromString(@"SpringBoard");
    if (![springBoardClass respondsToSelector:@selector(sharedApplication)]) {
        HBLogError(@"SpringBoard shared application is unavailable");
        return NO;
    }

    SpringBoard *springBoard = (SpringBoard *)[springBoardClass sharedApplication];
    if (![springBoard respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
        return NO;
    }

    [springBoard launchApplicationWithIdentifier:displayIdentifier suspended:NO];
    return YES;
}

@end

@implementation LATMediaActionListener {
    LATMediaHIDEventSender *_sender;
    LATMediaVolumeHUDPresenter *_volumeHUDPresenter;
    LATMediaNowPlayingApplicationLauncher *_nowPlayingApplicationLauncher;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sender = [[LATMediaHIDEventSender alloc] init];
        _volumeHUDPresenter = [[LATMediaVolumeHUDPresenter alloc] init];
        _nowPlayingApplicationLauncher = [[LATMediaNowPlayingApplicationLauncher alloc] init];
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
    LATMediaActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
    if (listenerName.length == 0 || !command) {
        return NO;
    }

    if (![command requiresSelectorMetadata]) {
        id title = [activator infoDictionaryValueOfKey:@"title" forListenerWithName:listenerName];
        return [title isKindOfClass:NSString.class] && [title length] > 0;
    }

    NSString *expectedSelector = command.selectorName;
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:expectedSelector];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    LATMediaActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Media action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerMetadataMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Media action %@ metadata does not match expected command", listenerName ?: @"");
        return;
    }

    switch (command.kind) {
    case LATMediaActionKindHID:
        [_sender sendCommand:command listenerName:listenerName];
        break;
    case LATMediaActionKindVolumeHUD:
        [_volumeHUDPresenter presentVolumeHUDForListenerName:listenerName];
        break;
    case LATMediaActionKindNowPlayingApplication:
        [_nowPlayingApplicationLauncher launchNowPlayingApplicationForListenerName:listenerName];
        break;
    }
}

- (BOOL)listenerMetadataMatchesCommand:(LATMediaActionCommand *)command activator:(LAActivator *)activator {
    if (![command requiresSelectorMetadata]) {
        id title = [activator infoDictionaryValueOfKey:@"title" forListenerWithName:command.listenerName];
        return [title isKindOfClass:NSString.class] && [title length] > 0;
    }

    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATMediaActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATMediaActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
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
            [[LATMediaActionCommand alloc]
                initWithNowPlayingApplicationListenerName:@"libactivator.audio.launch-playing-app"],
        ];

        NSMutableDictionary<NSString *, LATMediaActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATMediaActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
