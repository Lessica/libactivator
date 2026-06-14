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
#import "hardware/LATHardwareActionCommand.h"

#import <AudioToolbox/AudioToolbox.h>
#import <HBLog.h>

@interface LATHardwareActionListener ()
@property(nonatomic, strong) LATHIDEventSender *sender;
@end

@implementation LATHardwareActionListener

- (instancetype)init {
    self = [super init];
    if (self) {
        _sender = [[LATHIDEventSender alloc] init];
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
        [self.sender sendKeyboardUsagePage:command.page usage:command.usage reason:listenerName];
        break;
    case LATHardwareActionKindVibrate:
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
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
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_PlayOrPause],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.pause-playback"
                                                      selectorName:@"pauseMedia"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Pause],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.resume-playback"
                                                      selectorName:@"playMedia"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Play],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.next-track"
                                                      selectorName:@"nextTrack"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_ScanNextTrack],
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.ipod.previous-track"
                                                      selectorName:@"previousTrack"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_ScanPreviousTrack],
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
            [[LATHardwareActionCommand alloc] initWithListenerName:@"libactivator.system.take-screenshot"
                                                      selectorName:@"takeScreenshot"
                                                              page:kHIDPage_Consumer
                                                             usage:kHIDUsage_Csmr_Snapshot],
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
