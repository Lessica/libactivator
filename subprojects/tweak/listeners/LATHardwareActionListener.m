//
//  LATHardwareActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATHardwareActionListener.h"

#import "IOKitSPI.h"
#import "LATHIDEventSender.h"
#import "LATMediaEventSource.h"
#import "MediaRemote+Private.h"
#import "hardware/LATHardwareActionCommand.h"

#import <AudioToolbox/AudioToolbox.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface SBScreenshotManager : NSObject
@property(nonatomic, readonly, getter=isWritingScreenshot) BOOL writingScreenshot;
- (BOOL)_isWritingSnapshot;
- (void)saveScreenshot:(BOOL)save;
- (void)saveScreenshots;
@end

@interface UIApplication (LATHardwareScreenshotAction)
- (SBScreenshotManager *)screenshotManager;
- (void)takeScreenshot;
@end

@interface LATHardwareActionListener ()
@property(nonatomic, strong) LATHIDEventSender *sender;
@property(nonatomic, weak, nullable) LATMediaEventSource *mediaEventSource;
@end

@implementation LATHardwareActionListener

- (instancetype)init {
    return [self initWithMediaEventSource:nil];
}

- (instancetype)initWithMediaEventSource:(LATMediaEventSource *)mediaEventSource {
    self = [super init];
    if (self) {
        _sender = [[LATHIDEventSender alloc] init];
        _mediaEventSource = mediaEventSource;
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

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Hardware action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    event.handled = [self performCommand:command listenerName:listenerName];
}

- (BOOL)performCommand:(LATHardwareActionCommand *)command listenerName:(NSString *)listenerName {
    switch (command.kind) {
    case LATHardwareActionKindHID:
        return [self.sender sendKeyboardUsagePage:command.page usage:command.usage reason:listenerName];
    case LATHardwareActionKindMediaRemote:
        return [self performMediaRemoteCommand:command listenerName:listenerName];
    case LATHardwareActionKindScreenshot:
        return [self takeScreenshotForListenerName:listenerName];
    case LATHardwareActionKindVibrate:
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        return YES;
    }
}

- (BOOL)performMediaRemoteCommand:(LATHardwareActionCommand *)command listenerName:(NSString *)listenerName {
    MRMediaRemoteCommand mediaCommand = (MRMediaRemoteCommand)command.mediaRemoteCommand;
    if (mediaCommand == MRMediaRemoteCommandPlay || mediaCommand == MRMediaRemoteCommandPause) {
        BOOL isPlaying = NO;
        if (![self.mediaEventSource getKnownNowPlayingApplicationPlaying:&isPlaying]) {
            HBLogWarn(@"Skipping media action %@ because now-playing playback state is unknown", listenerName ?: @"");
            return NO;
        }

        if (mediaCommand == MRMediaRemoteCommandPlay && isPlaying) {
            return NO;
        }
        if (mediaCommand == MRMediaRemoteCommandPause && !isPlaying) {
            return NO;
        }
    }

    if (!MRMediaRemoteSendCommand(mediaCommand, nil)) {
        HBLogError(@"MediaRemote rejected media action %@", listenerName ?: @"");
        return NO;
    }
    return YES;
}

- (BOOL)takeScreenshotForListenerName:(NSString *)listenerName {
    UIApplication *application = UIApplication.sharedApplication;
    SBScreenshotManager *screenshotManager = nil;
    if ([application respondsToSelector:@selector(screenshotManager)]) {
        screenshotManager = [application screenshotManager];
    }

    if (screenshotManager) {
        if ([screenshotManager respondsToSelector:@selector(isWritingScreenshot)] &&
            screenshotManager.writingScreenshot) {
            return NO;
        }
        if ([screenshotManager respondsToSelector:@selector(_isWritingSnapshot)] &&
            [screenshotManager _isWritingSnapshot]) {
            return NO;
        }
        if ([screenshotManager respondsToSelector:@selector(saveScreenshot:)]) {
            [screenshotManager saveScreenshot:YES];
            return YES;
        }
        if ([screenshotManager respondsToSelector:@selector(saveScreenshots)]) {
            [screenshotManager saveScreenshots];
            return YES;
        }
    }

    if ([application respondsToSelector:@selector(takeScreenshot)]) {
        [application takeScreenshot];
        return YES;
    }

    HBLogError(@"SpringBoard cannot take screenshot for hardware action %@", listenerName ?: @"");
    return NO;
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
            [[LATHardwareActionCommand alloc]
                initWithMediaRemoteListenerName:@"libactivator.ipod.toggle-playback"
                                   selectorName:@"togglePlayback"
                             mediaRemoteCommand:MRMediaRemoteCommandTogglePlayPause],
            [[LATHardwareActionCommand alloc]
                initWithMediaRemoteListenerName:@"libactivator.ipod.pause-playback"
                                   selectorName:@"pauseMedia"
                             mediaRemoteCommand:MRMediaRemoteCommandPause],
            [[LATHardwareActionCommand alloc]
                initWithMediaRemoteListenerName:@"libactivator.ipod.resume-playback"
                                   selectorName:@"playMedia"
                             mediaRemoteCommand:MRMediaRemoteCommandPlay],
            [[LATHardwareActionCommand alloc]
                initWithMediaRemoteListenerName:@"libactivator.ipod.next-track"
                                   selectorName:@"nextTrack"
                             mediaRemoteCommand:MRMediaRemoteCommandNextTrack],
            [[LATHardwareActionCommand alloc]
                initWithMediaRemoteListenerName:@"libactivator.ipod.previous-track"
                                   selectorName:@"previousTrack"
                             mediaRemoteCommand:MRMediaRemoteCommandPreviousTrack],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.increase-volume"
                                                      selectorName:@"increaseVolume"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_VolumeIncrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.decrease-volume"
                                                      selectorName:@"decreaseVolume"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_VolumeDecrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.audio.toggle-output-mute"
                                                      selectorName:@"toggleOutputMute"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Mute],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.screen.brightness.increase"
                                                      selectorName:@"increaseBrightness"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_DisplayBrightnessIncrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.screen.brightness.decrease"
                                                      selectorName:@"decreaseBrightness"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_DisplayBrightnessDecrement],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.homebutton"
                                                      selectorName:@"homeButton"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Menu],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.sleepbutton"
                                                      selectorName:@"sleepButtonFromActivator:event:"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Power],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.keyboard.toggle-on-screen-keyboard"
                                                      selectorName:@"toggleOnScreenKeyboard"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_ALKeyboardLayout],
            [[LATHardwareActionCommand alloc] initWithScreenshotListenerName:@"libactivator.system.take-screenshot"
                                                                selectorName:@"takeScreenshot"],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.spotlight"
                                                      selectorName:@"spotlight"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_ACSearch],
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
