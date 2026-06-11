//
//  LATRingerActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATRingerActionListener.h"

#import "LATBuiltInListenerRegistry.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

extern int BKSHIDServicesGetRingerState(void);

@interface UIApplication (LATRingerPrivate)
- (void)_updateRingerState:(int)ringerState
               withVisuals:(BOOL)withVisuals
  updatePreferenceRegister:(BOOL)updatePreferenceRegister;
@end

@interface SBRingerControl : NSObject
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
- (void)activateRingerHUDFromMuteSwitch:(int)source;
@end

typedef NS_ENUM(NSUInteger, LATRingerActionKind) {
    LATRingerActionKindReset,
    LATRingerActionKindMute,
    LATRingerActionKindUnmute,
    LATRingerActionKindToggle,
};

@interface LATRingerActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATRingerActionKind kind;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATRingerActionKind)kind;
@end

@interface LATRingerStateResetter : NSObject
- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName;
@end

@interface LATRingerMuteController : NSObject
- (BOOL)applyCommand:(LATRingerActionCommand *)command;
@end

@implementation LATRingerActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATRingerActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = kind;
    }
    return self;
}

@end

@implementation LATRingerStateResetter

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
        HBLogError(@"Unable to reset ringer state for action %@ because SpringBoard does not support "
                   @"_updateRingerState:withVisuals:updatePreferenceRegister:",
                   listenerName ?: @"");
        return NO;
    }

    int ringerState = BKSHIDServicesGetRingerState();
    [application _updateRingerState:ringerState withVisuals:YES updatePreferenceRegister:NO];
    return YES;
}

@end

@implementation LATRingerMuteController

- (BOOL)applyCommand:(LATRingerActionCommand *)command {
    if (![NSThread isMainThread]) {
        __block BOOL applied = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            applied = [self applyCommand:command];
        });
        return applied;
    }

    SBRingerControl *ringerControl = LATBuiltInListenerRegistry.ringerControlInstance;
    if (!ringerControl) {
        HBLogError(@"Unable to apply ringer action %@ because SBRingerControl was not captured",
                   command.listenerName ?: @"");
        return NO;
    }

    if (![ringerControl respondsToSelector:@selector(setRingerMuted:)]) {
        HBLogError(@"SBRingerControl does not support setRingerMuted:");
        return NO;
    }

    BOOL muted = NO;
    if (command.kind == LATRingerActionKindToggle) {
        if (![ringerControl respondsToSelector:@selector(isRingerMuted)]) {
            HBLogError(@"SBRingerControl does not support isRingerMuted");
            return NO;
        }
        muted = ![ringerControl isRingerMuted];
    } else {
        muted = (command.kind == LATRingerActionKindMute);
    }

    [ringerControl setRingerMuted:muted];

    if ([ringerControl respondsToSelector:@selector(activateRingerHUDFromMuteSwitch:)]) {
        [ringerControl activateRingerHUDFromMuteSwitch:(muted ? 0 : 1)];
    }
    return YES;
}

@end

@implementation LATRingerActionListener {
    LATRingerStateResetter *_stateResetter;
    LATRingerMuteController *_muteController;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _stateResetter = [[LATRingerStateResetter alloc] init];
        _muteController = [[LATRingerMuteController alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATRingerActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATRingerActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Ringer action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Ringer action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    switch (command.kind) {
    case LATRingerActionKindReset:
        [_stateResetter resetRingerStateForListenerName:listenerName];
        break;
    case LATRingerActionKindMute:
    case LATRingerActionKindUnmute:
    case LATRingerActionKindToggle:
        [_muteController applyCommand:command];
        break;
    }
}

- (BOOL)listenerSelectorMatchesCommand:(LATRingerActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATRingerActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATRingerActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATRingerActionCommand *> *commandList = @[
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.reset-ringer-state"
                                                    selectorName:@"resetRingerState"
                                                            kind:LATRingerActionKindReset],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.mute-ringer"
                                                    selectorName:@"muteRinger"
                                                            kind:LATRingerActionKindMute],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.unmute-ringer"
                                                    selectorName:@"unmuteRinger"
                                                            kind:LATRingerActionKindUnmute],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.toggle-ringer-mute"
                                                    selectorName:@"toggleRingerMute"
                                                            kind:LATRingerActionKindToggle],
        ];

        NSMutableDictionary<NSString *, LATRingerActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATRingerActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
