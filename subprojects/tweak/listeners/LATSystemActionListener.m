//
//  LATSystemActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATSystemActionListener.h"

#import "LATApplicationLauncher.h"
#import "LATBuiltInListenerRegistry.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

extern int BKSHIDServicesGetRingerState(void);
extern void MRMediaRemoteSetWantsNowPlayingNotifications(Boolean wantsNotifications) __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t queue,
                                                           void (^completion)(CFStringRef displayID))
    __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationPID(dispatch_queue_t queue, void (^completion)(int PID))
    __attribute__((weak_import));
extern CFStringRef SBSCopyDisplayIdentifierForProcessID(pid_t PID) __attribute__((weak_import));

@interface UIApplication (LATSystemRingerPrivate)
- (void)_updateRingerState:(int)ringerState
                 withVisuals:(BOOL)withVisuals
    updatePreferenceRegister:(BOOL)updatePreferenceRegister;
@end

@interface SBVolumeControl : NSObject
- (float)_effectiveVolume;
- (void)_presentVolumeHUDWithVolume:(float)volume;
@end

@interface SBRingerControl : NSObject
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
- (void)activateRingerHUDFromMuteSwitch:(int)source;
@end

@interface SBSServiceFacilityClient : NSObject
+ (id)checkOutClientWithClass:(Class)clientClass;
@end

@interface SBSSystemServiceClient : NSObject
- (void)resetToHomeScreenAnimated:(BOOL)animated;
- (void)resetToHomeScreenAnimated:(BOOL)animated useSafeTransitions:(BOOL)useSafeTransitions;
@end

typedef NS_ENUM(NSUInteger, LATSystemActionKind) {
    LATSystemActionKindVolumeHUD,
    LATSystemActionKindNowPlayingApplication,
    LATSystemActionKindRingerReset,
    LATSystemActionKindRingerMute,
    LATSystemActionKindRingerUnmute,
    LATSystemActionKindRingerToggle,
    LATSystemActionKindFirstSpringBoardPage,
};

@interface LATSystemActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATSystemActionKind kind;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATSystemActionKind)kind;
@end

@interface LATSystemVolumeHUDPresenter : NSObject
- (BOOL)presentVolumeHUDForListenerName:(NSString *)listenerName;
@end

@interface LATSystemNowPlayingApplicationLauncher : NSObject
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher;
- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName;
@end

@interface LATSystemRingerStateResetter : NSObject
- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName;
@end

@interface LATSystemRingerMuteController : NSObject
- (BOOL)applyCommand:(LATSystemActionCommand *)command;
@end

@interface LATSystemHomeScreenController : NSObject
- (BOOL)resetToFirstSpringBoardPageForListenerName:(NSString *)listenerName;
@end

@interface LATSystemNowPlayingApplicationLauncher ()
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;
@end

@interface LATSystemActionListener ()
@property(nonatomic, strong) LATSystemVolumeHUDPresenter *volumeHUDPresenter;
@property(nonatomic, strong) LATSystemNowPlayingApplicationLauncher *nowPlayingApplicationLauncher;
@property(nonatomic, strong) LATSystemRingerStateResetter *ringerStateResetter;
@property(nonatomic, strong) LATSystemRingerMuteController *ringerMuteController;
@property(nonatomic, strong) LATSystemHomeScreenController *homeScreenController;
@end

@implementation LATSystemActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATSystemActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = kind;
    }
    return self;
}

@end

@implementation LATSystemVolumeHUDPresenter

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
        HBLogError(@"Unable to present volume HUD for system action %@ because SBVolumeControl was not captured",
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

@implementation LATSystemNowPlayingApplicationLauncher

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher {
    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
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

    HBLogError(@"Unable to launch now-playing application for system action %@ because MediaRemote identity APIs are "
               @"unavailable",
               listenerName ?: @"");
    return NO;
}

- (void)requestNowPlayingApplicationDisplayIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationDisplayID(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(CFStringRef displayID) {
            NSString *identifier = [(__bridge NSString *)displayID copy];
            if (identifier.length > 0) {
                [self launchApplicationWithIdentifier:identifier listenerName:listenerName];
                return;
            }

            HBLogWarn(@"MediaRemote returned no now-playing application display identifier for system action %@",
                      listenerName ?: @"");
            if (MRMediaRemoteGetNowPlayingApplicationPID && SBSCopyDisplayIdentifierForProcessID) {
                [self requestNowPlayingApplicationProcessIdentifierForListenerName:listenerName];
            }
        });
}

- (void)requestNowPlayingApplicationProcessIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationPID(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int PID) {
        if (PID <= 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application process identifier for system action %@",
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

    if (![self.applicationLauncher enqueueLaunchApplicationWithIdentifier:displayIdentifier unlockDevice:YES]) {
        HBLogError(@"Unable to enqueue now-playing application %@ for system action %@", displayIdentifier,
                   listenerName ?: @"");
    }
}

@end

@implementation LATSystemRingerStateResetter

- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName {
    if (![NSThread isMainThread]) {
        __block BOOL reset = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            reset = [self resetRingerStateForListenerName:listenerName];
        });
        return reset;
    }

    UIApplication *application = UIApplication.sharedApplication;
    SEL updateSelector = @selector(_updateRingerState:withVisuals:updatePreferenceRegister:);
    if (!application || ![application respondsToSelector:updateSelector]) {
        HBLogError(@"Unable to reset ringer state for system action %@ because SpringBoard does not support "
                   @"_updateRingerState:withVisuals:updatePreferenceRegister:",
                   listenerName ?: @"");
        return NO;
    }

    int ringerState = BKSHIDServicesGetRingerState();
    [application _updateRingerState:ringerState withVisuals:YES updatePreferenceRegister:NO];
    return YES;
}

@end

@implementation LATSystemRingerMuteController

- (BOOL)applyCommand:(LATSystemActionCommand *)command {
    if (![NSThread isMainThread]) {
        __block BOOL applied = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            applied = [self applyCommand:command];
        });
        return applied;
    }

    SBRingerControl *ringerControl = LATBuiltInListenerRegistry.ringerControlInstance;
    if (!ringerControl) {
        HBLogError(@"Unable to apply ringer system action %@ because SBRingerControl was not captured",
                   command.listenerName ?: @"");
        return NO;
    }

    if (![ringerControl respondsToSelector:@selector(setRingerMuted:)]) {
        HBLogError(@"SBRingerControl does not support setRingerMuted:");
        return NO;
    }

    BOOL muted = NO;
    if (command.kind == LATSystemActionKindRingerToggle) {
        if (![ringerControl respondsToSelector:@selector(isRingerMuted)]) {
            HBLogError(@"SBRingerControl does not support isRingerMuted");
            return NO;
        }
        muted = ![ringerControl isRingerMuted];
    } else {
        muted = (command.kind == LATSystemActionKindRingerMute);
    }

    [ringerControl setRingerMuted:muted];

    if ([ringerControl respondsToSelector:@selector(activateRingerHUDFromMuteSwitch:)]) {
        [ringerControl activateRingerHUDFromMuteSwitch:(muted ? 0 : 1)];
    }
    return YES;
}

@end

@implementation LATSystemHomeScreenController

- (BOOL)resetToFirstSpringBoardPageForListenerName:(NSString *)listenerName {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Class facilityClass = NSClassFromString(@"SBSServiceFacilityClient");
        Class serviceClass = NSClassFromString(@"SBSSystemServiceClient");
        if (![facilityClass respondsToSelector:@selector(checkOutClientWithClass:)] || !serviceClass) {
            HBLogError(@"Unable to reset to first SpringBoard page for system action %@ because SBS system service is "
                       @"unavailable",
                       listenerName ?: @"");
            return;
        }

        SBSSystemServiceClient *service = [facilityClass checkOutClientWithClass:serviceClass];
        if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)]) {
            [service resetToHomeScreenAnimated:YES useSafeTransitions:YES];
        } else if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:)]) {
            [service resetToHomeScreenAnimated:YES];
        } else {
            HBLogError(@"SBSSystemServiceClient does not support resetToHomeScreenAnimated:");
        }
    });
    return YES;
}

@end

@implementation LATSystemActionListener

- (instancetype)init {
    return [self initWithApplicationLauncher:[[LATApplicationLauncher alloc] init]];
}

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher {
    self = [super init];
    if (self) {
        _volumeHUDPresenter = [[LATSystemVolumeHUDPresenter alloc] init];
        _nowPlayingApplicationLauncher =
            [[LATSystemNowPlayingApplicationLauncher alloc] initWithApplicationLauncher:applicationLauncher];
        _ringerStateResetter = [[LATSystemRingerStateResetter alloc] init];
        _ringerMuteController = [[LATSystemRingerMuteController alloc] init];
        _homeScreenController = [[LATSystemHomeScreenController alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATSystemActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATSystemActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"System action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerMetadataMatchesCommand:command activator:activator]) {
        HBLogWarn(@"System action %@ metadata does not match expected command", listenerName ?: @"");
        return;
    }

    switch (command.kind) {
    case LATSystemActionKindVolumeHUD:
        [self.volumeHUDPresenter presentVolumeHUDForListenerName:listenerName];
        break;
    case LATSystemActionKindNowPlayingApplication:
        [self.nowPlayingApplicationLauncher launchNowPlayingApplicationForListenerName:listenerName];
        break;
    case LATSystemActionKindRingerReset:
        [self.ringerStateResetter resetRingerStateForListenerName:listenerName];
        break;
    case LATSystemActionKindRingerMute:
    case LATSystemActionKindRingerUnmute:
    case LATSystemActionKindRingerToggle:
        [self.ringerMuteController applyCommand:command];
        break;
    case LATSystemActionKindFirstSpringBoardPage:
        [self.homeScreenController resetToFirstSpringBoardPageForListenerName:listenerName];
        break;
    }
}

- (BOOL)listenerMetadataMatchesCommand:(LATSystemActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATSystemActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATSystemActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATSystemActionCommand *> *commandList = @[
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.show-volume-bar"
                                                    selectorName:@"showVolumeBar"
                                                            kind:LATSystemActionKindVolumeHUD],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.launch-playing-app"
                                                    selectorName:@"launchPlayingApp"
                                                            kind:LATSystemActionKindNowPlayingApplication],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.reset-ringer-state"
                                                    selectorName:@"resetRingerState"
                                                            kind:LATSystemActionKindRingerReset],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.mute-ringer"
                                                    selectorName:@"muteRinger"
                                                            kind:LATSystemActionKindRingerMute],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.unmute-ringer"
                                                    selectorName:@"unmuteRinger"
                                                            kind:LATSystemActionKindRingerUnmute],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.audio.toggle-ringer-mute"
                                                    selectorName:@"toggleRingerMute"
                                                            kind:LATSystemActionKindRingerToggle],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.first-springboard-page"
                                                    selectorName:@"firstSpringBoardPage"
                                                            kind:LATSystemActionKindFirstSpringBoardPage],
        ];

        NSMutableDictionary<NSString *, LATSystemActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATSystemActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
