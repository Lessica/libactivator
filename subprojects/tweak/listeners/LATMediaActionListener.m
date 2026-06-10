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
#import <UIKit/UIKit.h>
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

@interface LATMediaActionListener ()
+ (id)volumeControlInstance;
@end

static __weak id gCapturedVolumeControl = nil;

#if LA_TESTING
static LATMediaActionSendHandler gTestingSendHandler = nil;
static NSString *gTestingLastSentListenerName = nil;
static uint32_t gTestingLastSentPage = 0;
static uint32_t gTestingLastSentUsage = 0;
static NSMutableArray<NSString *> *gTestingSentPhases = nil;
static NSMutableDictionary<NSString *, NSString *> *gTestingSelectors = nil;
static BOOL gTestingNowPlayingApplicationIdentifierSet = NO;
static NSString *gTestingNowPlayingApplicationIdentifier = nil;
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
#if LA_TESTING
    gTestingLastSentListenerName = [listenerName copy];
    gTestingLastSentPage = command.page;
    gTestingLastSentUsage = command.usage;
    if (!gTestingSentPhases) {
        gTestingSentPhases = [[NSMutableArray alloc] init];
    }
    [gTestingSentPhases addObject:@"down"];
    [gTestingSentPhases addObject:@"up"];
    if (gTestingSendHandler) {
        return gTestingSendHandler(listenerName ?: @"", command.page, command.usage);
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
    gTestingLastSentListenerName = [listenerName copy];
    gTestingLastSentPage = 0;
    gTestingLastSentUsage = 0;
    if (!gTestingSentPhases) {
        gTestingSentPhases = [[NSMutableArray alloc] init];
    }
    [gTestingSentPhases addObject:@"volume-hud"];
    if (gTestingSendHandler) {
        return gTestingSendHandler(listenerName ?: @"", 0, 0);
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

@implementation LATMediaNowPlayingApplicationLauncher

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName {
#if LA_TESTING
    if (gTestingNowPlayingApplicationIdentifierSet && gTestingNowPlayingApplicationIdentifier.length == 0) {
        return NO;
    }

    gTestingLastSentListenerName = [listenerName copy];
    gTestingLastSentPage = 0;
    gTestingLastSentUsage = 0;
    if (!gTestingSentPhases) {
        gTestingSentPhases = [[NSMutableArray alloc] init];
    }
    [gTestingSentPhases addObject:@"launch-application"];
    if (gTestingSendHandler) {
        return gTestingSendHandler(listenerName ?: @"", 0, 0);
    }
    return YES;
#endif

    if (![NSThread isMainThread]) {
        __block BOOL launched = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            launched = [self launchNowPlayingApplicationForListenerName:listenerName];
        });
        return launched;
    }

    id application = [self nowPlayingApplication];
    if (!application) {
        HBLogWarn(@"Unable to launch now-playing application for media action %@ because no now-playing application "
                  @"was found",
                  listenerName ?: @"");
        return NO;
    }

    NSString *displayIdentifier = [self displayIdentifierForApplication:application];
    if (displayIdentifier.length == 0) {
        HBLogError(
            @"Unable to launch now-playing application for media action %@ because application has no identifier",
            listenerName ?: @"");
        return NO;
    }

    if ([self launchApplicationWithIdentifier:displayIdentifier]) {
        return YES;
    }

    if ([self activateApplication:application]) {
        return YES;
    }

    HBLogError(@"Unable to launch now-playing application %@ for media action %@", displayIdentifier,
               listenerName ?: @"");
    return NO;
}

- (id)nowPlayingApplication {
    Class mediaControllerClass = NSClassFromString(@"SBMediaController");
    if (![mediaControllerClass respondsToSelector:@selector(sharedInstance)]) {
        HBLogError(@"SBMediaController is unavailable");
        return nil;
    }

    id mediaController = [mediaControllerClass sharedInstance];
    SEL nowPlayingApplicationSelector = NSSelectorFromString(@"nowPlayingApplication");
    if (![mediaController respondsToSelector:nowPlayingApplicationSelector]) {
        HBLogError(@"SBMediaController does not support nowPlayingApplication");
        return nil;
    }

    id (*nowPlayingApplication)(id, SEL) =
        (id(*)(id, SEL))[mediaController methodForSelector:nowPlayingApplicationSelector];
    return nowPlayingApplication(mediaController, nowPlayingApplicationSelector);
}

- (NSString *)displayIdentifierForApplication:(id)application {
    SEL displayIdentifierSelector = NSSelectorFromString(@"displayIdentifier");
    if ([application respondsToSelector:displayIdentifierSelector]) {
        NSString *displayIdentifier =
            ((NSString * (*)(id, SEL))[application methodForSelector:displayIdentifierSelector])(
                application, displayIdentifierSelector);
        if ([displayIdentifier isKindOfClass:NSString.class] && displayIdentifier.length > 0) {
            return displayIdentifier;
        }
    }

    SEL bundleIdentifierSelector = NSSelectorFromString(@"bundleIdentifier");
    if ([application respondsToSelector:bundleIdentifierSelector]) {
        NSString *bundleIdentifier =
            ((NSString * (*)(id, SEL))[application methodForSelector:bundleIdentifierSelector])(
                application, bundleIdentifierSelector);
        if ([bundleIdentifier isKindOfClass:NSString.class] && bundleIdentifier.length > 0) {
            return bundleIdentifier;
        }
    }

    return nil;
}

- (BOOL)launchApplicationWithIdentifier:(NSString *)displayIdentifier {
    Class springBoardClass = NSClassFromString(@"SpringBoard");
    id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                         ? [springBoardClass sharedApplication]
                         : UIApplication.sharedApplication;
    SEL launchSelector = NSSelectorFromString(@"launchApplicationWithIdentifier:suspended:");
    if (![springBoard respondsToSelector:launchSelector]) {
        return NO;
    }

    void (*launchApplication)(id, SEL, NSString *, BOOL) =
        (void (*)(id, SEL, NSString *, BOOL))[springBoard methodForSelector:launchSelector];
    launchApplication(springBoard, launchSelector, displayIdentifier, NO);
    return YES;
}

- (BOOL)activateApplication:(id)application {
    Class uiControllerClass = NSClassFromString(@"SBUIController");
    if (![uiControllerClass respondsToSelector:@selector(sharedInstance)]) {
        return NO;
    }

    id uiController = [uiControllerClass sharedInstance];
    SEL activateSelector = NSSelectorFromString(@"activateApplicationAnimated:");
    if (![uiController respondsToSelector:activateSelector]) {
        activateSelector = NSSelectorFromString(@"activateApplicationFromSwitcher:");
        if (![uiController respondsToSelector:activateSelector]) {
            return NO;
        }
    }

    void (*activateApplication)(id, SEL, id) = (void (*)(id, SEL, id))[uiController methodForSelector:activateSelector];
    activateApplication(uiController, activateSelector, application);
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

#if LA_TESTING
    NSString *testingSelector = gTestingSelectors[command.listenerName];
    if (testingSelector) {
        return [testingSelector isEqualToString:command.selectorName];
    }
#endif

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

+ (void)noteVolumeControlInstance:(id)volumeControl {
    if (volumeControl) {
        gCapturedVolumeControl = volumeControl;
    }
}

+ (id)volumeControlInstance {
    return gCapturedVolumeControl;
}

#if LA_TESTING
+ (void)setTestingSendHandler:(LATMediaActionSendHandler)handler {
    gTestingSendHandler = [handler copy];
}

+ (void)setTestingSelector:(NSString *)selector forListenerName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return;
    }
    if (!gTestingSelectors) {
        gTestingSelectors = [[NSMutableDictionary alloc] init];
    }
    if (selector) {
        gTestingSelectors[listenerName] = selector;
    } else {
        [gTestingSelectors removeObjectForKey:listenerName];
    }
}

+ (void)setTestingNowPlayingApplicationIdentifier:(NSString *)identifier {
    gTestingNowPlayingApplicationIdentifierSet = YES;
    gTestingNowPlayingApplicationIdentifier = [identifier copy];
}

+ (NSString *)testingLastSentListenerName {
    return gTestingLastSentListenerName;
}

+ (uint32_t)testingLastSentPage {
    return gTestingLastSentPage;
}

+ (uint32_t)testingLastSentUsage {
    return gTestingLastSentUsage;
}

+ (NSArray<NSString *> *)testingSentPhases {
    return [gTestingSentPhases copy] ?: @[];
}

+ (void)resetTestingState {
    gTestingSendHandler = nil;
    gTestingLastSentListenerName = nil;
    gTestingLastSentPage = 0;
    gTestingLastSentUsage = 0;
    gTestingNowPlayingApplicationIdentifierSet = NO;
    gTestingNowPlayingApplicationIdentifier = nil;
    [gTestingSentPhases removeAllObjects];
    [gTestingSelectors removeAllObjects];
}
#endif

@end
