//
//  LATSystemActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATSystemActionListener.h"

#import "LATApplicationLauncher.h"
#import "LATBuiltInRegistry.h"
#import "system/LATSystemActionCommand.h"
#import "system/LATSystemHomeScreenController.h"
#import "system/LATSystemNowPlayingApplicationLauncher.h"
#import "system/LATSystemRingerMuteController.h"
#import "system/LATSystemRingerStateResetter.h"
#import "system/LATSystemVolumeHUDPresenter.h"

#import <HBLog.h>

@interface LATSystemActionListener ()

// Dependencies
@property(nonatomic, weak, nullable) LATBuiltInRegistry *registry;

// Action executors
@property(nonatomic, strong) LATSystemHomeScreenController *homeScreenController;
@property(nonatomic, strong) LATSystemNowPlayingApplicationLauncher *nowPlayingApplicationLauncher;
@property(nonatomic, strong) LATSystemRingerMuteController *ringerMuteController;
@property(nonatomic, strong) LATSystemRingerStateResetter *ringerStateResetter;
@property(nonatomic, strong) LATSystemVolumeHUDPresenter *volumeHUDPresenter;

@end

@implementation LATSystemActionListener

- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher registry:(LATBuiltInRegistry *)registry {
    self = [super init];
    if (self) {
        _registry = registry;
        _volumeHUDPresenter = [[LATSystemVolumeHUDPresenter alloc] initWithRegistry:_registry];
        _nowPlayingApplicationLauncher =
            [[LATSystemNowPlayingApplicationLauncher alloc] initWithApplicationLauncher:launcher
                                                                       mediaEventSource:_registry.mediaEventSource];
        _ringerStateResetter = [[LATSystemRingerStateResetter alloc] init];
        _ringerMuteController = [[LATSystemRingerMuteController alloc] initWithRegistry:_registry];
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
