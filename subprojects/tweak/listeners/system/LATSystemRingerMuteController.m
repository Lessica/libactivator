//
//  LATSystemRingerMuteController.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemRingerMuteController.h"

#import "LATBuiltInListenerRegistry.h"
#import "system/LATSystemActionCommand.h"

#import <HBLog.h>

@interface SBRingerControl : NSObject
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
- (void)activateRingerHUDFromMuteSwitch:(int)source;
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
