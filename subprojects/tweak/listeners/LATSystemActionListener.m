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
#import "system/LATSystemAssistantController.h"
#import "system/LATSystemCenterController.h"
#import "system/LATSystemHapticFeedbackController.h"
#import "system/LATSystemHomeScreenController.h"
#import "system/LATSystemLocalBackController.h"
#import "system/LATSystemLockScreenController.h"
#import "system/LATSystemNowPlayingApplicationLauncher.h"
#import "system/LATSystemOrientationController.h"
#import "system/LATSystemPowerController.h"
#import "system/LATSystemPowerMenuController.h"
#import "system/LATSystemReachabilityController.h"
#import "system/LATSystemRingerMuteController.h"
#import "system/LATSystemRingerStateResetter.h"
#import "system/LATSystemScreenshotController.h"
#import "system/LATSystemSwitcherController.h"
#import "system/LATSystemVoiceControlController.h"
#import "system/LATSystemVolumeHUDPresenter.h"
#import "system/LATSystemWalletController.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface LATSystemActionListener ()

// Dependencies
@property(nonatomic, weak, nullable) LATBuiltInRegistry *registry;

// Action executors
@property(nonatomic, strong) LATSystemHomeScreenController *homeScreenController;
@property(nonatomic, strong) LATSystemLockScreenController *lockScreenController;
@property(nonatomic, strong) LATSystemNowPlayingApplicationLauncher *nowPlayingApplicationLauncher;
@property(nonatomic, strong) LATSystemAssistantController *assistantController;
@property(nonatomic, strong) LATSystemCenterController *centerController;
@property(nonatomic, strong) LATSystemHapticFeedbackController *hapticFeedbackController;
@property(nonatomic, strong) LATSystemLocalBackController *localBackController;
@property(nonatomic, strong) LATSystemOrientationController *orientationController;
@property(nonatomic, strong) LATSystemPowerController *powerController;
@property(nonatomic, strong) LATSystemPowerMenuController *powerMenuController;
@property(nonatomic, strong) LATSystemReachabilityController *reachabilityController;
@property(nonatomic, strong) LATSystemRingerMuteController *ringerMuteController;
@property(nonatomic, strong) LATSystemRingerStateResetter *ringerStateResetter;
@property(nonatomic, strong) LATSystemScreenshotController *screenshotController;
@property(nonatomic, strong) LATSystemSwitcherController *switcherController;
@property(nonatomic, strong) LATSystemVolumeHUDPresenter *volumeHUDPresenter;
@property(nonatomic, strong) LATSystemVoiceControlController *voiceControlController;
@property(nonatomic, strong) LATSystemWalletController *walletController;

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
        _lockScreenController =
            [[LATSystemLockScreenController alloc] initWithRuntimeStateSource:_registry.runtimeStateSource];
        _assistantController = [[LATSystemAssistantController alloc] init];
        _centerController = [[LATSystemCenterController alloc] initWithRuntimeStateSource:_registry.runtimeStateSource];
        _hapticFeedbackController = [[LATSystemHapticFeedbackController alloc] init];
        _localBackController = [[LATSystemLocalBackController alloc] init];
        _orientationController = [[LATSystemOrientationController alloc] init];
        _powerController = [[LATSystemPowerController alloc] init];
        _powerMenuController = [[LATSystemPowerMenuController alloc] init];
        _reachabilityController = [[LATSystemReachabilityController alloc] init];
        _screenshotController = [[LATSystemScreenshotController alloc] init];
        _switcherController = [[LATSystemSwitcherController alloc] init];
        _voiceControlController = [[LATSystemVoiceControlController alloc] init];
        _walletController = [[LATSystemWalletController alloc] init];
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
    case LATSystemActionKindLockScreenShow:
        [self.lockScreenController showLockScreenForListenerName:listenerName];
        break;
    case LATSystemActionKindLockScreenDismiss:
        [self.lockScreenController dismissLockScreenForListenerName:listenerName];
        break;
    case LATSystemActionKindLockScreenToggle:
        [self.lockScreenController toggleLockScreenForListenerName:listenerName];
        break;
    case LATSystemActionKindLockAndWipeCredentials:
        [self.lockScreenController lockAndWipeCredentialsForListenerName:listenerName];
        break;
    case LATSystemActionKindActivateControlCenter:
        [self.centerController activateControlCenterForListenerName:listenerName];
        break;
    case LATSystemActionKindShowNowPlayingControls:
        [self.centerController showNowPlayingControlsForListenerName:listenerName];
        break;
    case LATSystemActionKindActivateNotificationCenter:
        [self.centerController activateNotificationCenterForListenerName:listenerName];
        break;
    case LATSystemActionKindActivateReachability:
        [self.reachabilityController activateReachabilityForListenerName:listenerName];
        break;
    case LATSystemActionKindActivateSwitcher:
        [self.switcherController activateSwitcherForListenerName:listenerName];
        break;
    case LATSystemActionKindEditScreenshot:
        [self.screenshotController editScreenshotForListenerName:listenerName];
        break;
    case LATSystemActionKindPowerMenu:
        [self.powerMenuController showPowerMenuForListenerName:listenerName];
        break;
    case LATSystemActionKindRespring:
        [self.powerController respringForListenerName:listenerName];
        break;
    case LATSystemActionKindHardRespring:
        [self.powerController hardRespringForListenerName:listenerName];
        break;
    case LATSystemActionKindSafeMode:
        [self.powerController safeModeForListenerName:listenerName];
        break;
    case LATSystemActionKindPowerDown:
        [self.powerController powerDownForListenerName:listenerName];
        break;
    case LATSystemActionKindReboot:
        [self.powerController rebootForListenerName:listenerName];
        break;
    case LATSystemActionKindHapticFlick:
        [self.hapticFeedbackController performHapticFeedbackType:LATSystemHapticFeedbackTypeFlick
                                                    listenerName:listenerName];
        break;
    case LATSystemActionKindHapticTap:
        [self.hapticFeedbackController performHapticFeedbackType:LATSystemHapticFeedbackTypeTap
                                                    listenerName:listenerName];
        break;
    case LATSystemActionKindHapticQuirk:
        [self.hapticFeedbackController performHapticFeedbackType:LATSystemHapticFeedbackTypeQuirk
                                                    listenerName:listenerName];
        break;
    case LATSystemActionKindBack:
        event.handled = [self.localBackController performBackForEvent:event
                                                            activator:activator
                                                         listenerName:listenerName];
        break;
    case LATSystemActionKindLocalBack:
        [self.localBackController performLocalBackForListenerName:listenerName];
        break;
    case LATSystemActionKindRotateLandscapeLeft:
        [self.orientationController rotateToOrientation:UIInterfaceOrientationLandscapeLeft listenerName:listenerName];
        break;
    case LATSystemActionKindRotateLandscapeRight:
        [self.orientationController rotateToOrientation:UIInterfaceOrientationLandscapeRight listenerName:listenerName];
        break;
    case LATSystemActionKindRotatePortrait:
        [self.orientationController rotateToOrientation:UIInterfaceOrientationPortrait listenerName:listenerName];
        break;
    case LATSystemActionKindRotatePortraitUpsideDown:
        [self.orientationController rotateToOrientation:UIInterfaceOrientationPortraitUpsideDown
                                           listenerName:listenerName];
        break;
    case LATSystemActionKindVirtualAssistant:
        [self.assistantController activateVirtualAssistantForListenerName:listenerName];
        break;
    case LATSystemActionKindVoiceControl:
        [self.voiceControlController toggleVoiceControlForListenerName:listenerName];
        break;
    case LATSystemActionKindWallet:
        [self.walletController activateWalletForListenerName:listenerName];
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
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.lockscreen.show"
                                                    selectorName:@"showLockScreen"
                                                            kind:LATSystemActionKindLockScreenShow],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.lockscreen.dismiss"
                                                    selectorName:@"dismissLockScreen"
                                                            kind:LATSystemActionKindLockScreenDismiss],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.lockscreen.toggle"
                                                    selectorName:@"toggleLockScreen"
                                                            kind:LATSystemActionKindLockScreenToggle],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.lock-and-wipe-credentials"
                                                    selectorName:@"wipeCredentials"
                                                            kind:LATSystemActionKindLockAndWipeCredentials],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.activate-control-center"
                                                    selectorName:@"showControlCenter"
                                                            kind:LATSystemActionKindActivateControlCenter],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.ipod.music-controls"
                                                    selectorName:@"musicControls"
                                                            kind:LATSystemActionKindShowNowPlayingControls],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.show-now-playing-bar"
                                                    selectorName:@"showNowPlayingBar"
                                                            kind:LATSystemActionKindShowNowPlayingControls],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.activate-notification-center"
                                                    selectorName:@"activateNotificationCenter"
                                                            kind:LATSystemActionKindActivateNotificationCenter],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.activate-reachability"
                                                    selectorName:@"activateReachability"
                                                            kind:LATSystemActionKindActivateReachability],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.activate-switcher"
                                                    selectorName:@"activateSwitcherFromActivator:event:"
                                                            kind:LATSystemActionKindActivateSwitcher],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.edit-screenshot"
                                                    selectorName:@"editScreenshot"
                                                            kind:LATSystemActionKindEditScreenshot],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.power-menu"
                                                    selectorName:@"powerDownView"
                                                            kind:LATSystemActionKindPowerMenu],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.respring"
                                                    selectorName:@"respring"
                                                            kind:LATSystemActionKindRespring],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.hard-respring"
                                                    selectorName:@"hardRespring"
                                                            kind:LATSystemActionKindHardRespring],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.safemode"
                                                    selectorName:@"safeMode"
                                                            kind:LATSystemActionKindSafeMode],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.powerdown"
                                                    selectorName:@"powerDown"
                                                            kind:LATSystemActionKindPowerDown],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.reboot"
                                                    selectorName:@"reboot"
                                                            kind:LATSystemActionKindReboot],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.haptic.flick"
                                                    selectorName:@"tapticWithActivator:event:listenerName:"
                                                            kind:LATSystemActionKindHapticFlick],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.haptic.tap"
                                                    selectorName:@"tapticWithActivator:event:listenerName:"
                                                            kind:LATSystemActionKindHapticTap],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.haptic.quirk"
                                                    selectorName:@"tapticWithActivator:event:listenerName:"
                                                            kind:LATSystemActionKindHapticQuirk],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.back"
                                                    selectorName:@"goBackWithActivator:event:"
                                                            kind:LATSystemActionKindBack],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.local-back"
                                                    selectorName:@"localBack"
                                                            kind:LATSystemActionKindLocalBack],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.rotate.landscape-left"
                                                    selectorName:@"rotateLandscapeLeft"
                                                            kind:LATSystemActionKindRotateLandscapeLeft],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.rotate.landscape-right"
                                                    selectorName:@"rotateLandscapeRight"
                                                            kind:LATSystemActionKindRotateLandscapeRight],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.rotate.portrait"
                                                    selectorName:@"rotatePortrait"
                                                            kind:LATSystemActionKindRotatePortrait],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.rotate.portrait-upside-down"
                                                    selectorName:@"rotatePortraitUpsideDown"
                                                            kind:LATSystemActionKindRotatePortraitUpsideDown],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.virtual-assistant"
                                                    selectorName:@"activateSiri"
                                                            kind:LATSystemActionKindVirtualAssistant],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.voice-control"
                                                    selectorName:@"voiceControl"
                                                            kind:LATSystemActionKindVoiceControl],
            [[LATSystemActionCommand alloc] initWithListenerName:@"libactivator.system.wallet"
                                                    selectorName:@"openWallet"
                                                            kind:LATSystemActionKindWallet],
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
