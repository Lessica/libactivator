//
//  LATRingerActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATRingerActionListener.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef int (*LATRingerStateGetter)(void);

typedef NS_ENUM(NSUInteger, LATRingerActionKind) {
    LATRingerActionKindReset,
    LATRingerActionKindMute,
    LATRingerActionKindUnmute,
    LATRingerActionKindToggle,
};

@interface LATRingerActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, copy, readonly) NSString *testingPhase;
@property(nonatomic, assign, readonly) LATRingerActionKind kind;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                        testingPhase:(NSString *)testingPhase
                                kind:(LATRingerActionKind)kind;
@end

@interface LATRingerStateResetter : NSObject
- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName testingPhase:(NSString *)testingPhase;
@end

@interface LATRingerMuteController : NSObject
- (BOOL)applyCommand:(LATRingerActionCommand *)command;
@end

@interface LATRingerActionListener ()
+ (id)ringerControlInstance;
@end

static __weak id LATCapturedRingerControl = nil;

#if LA_TESTING
static LATRingerActionHandler LATTestingActionHandler = nil;
static NSString *LATTestingLastActionListenerName = nil;
static NSString *LATTestingLastActionPhase = nil;
static NSMutableDictionary<NSString *, NSString *> *LATTestingSelectors = nil;
#endif

@implementation LATRingerActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                        testingPhase:(NSString *)testingPhase
                                kind:(LATRingerActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _testingPhase = [testingPhase copy];
        _kind = kind;
    }
    return self;
}

@end

@implementation LATRingerStateResetter

- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName testingPhase:(NSString *)testingPhase {
#if LA_TESTING
    LATTestingLastActionListenerName = [listenerName copy];
    LATTestingLastActionPhase = [testingPhase copy];
    if (LATTestingActionHandler) {
        return LATTestingActionHandler(listenerName ?: @"", testingPhase ?: @"");
    }
#endif

    if (![NSThread isMainThread]) {
        __block BOOL reset = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            reset = [self resetRingerStateForListenerName:listenerName testingPhase:testingPhase];
        });
        return reset;
    }

    LATRingerStateGetter getRingerState = (LATRingerStateGetter)dlsym(RTLD_DEFAULT, "BKSHIDServicesGetRingerState");
    if (!getRingerState) {
        HBLogError(@"Unable to reset ringer state for action %@ because BKSHIDServicesGetRingerState was not found",
                   listenerName ?: @"");
        return NO;
    }

    UIApplication *application = UIApplication.sharedApplication;
    SEL updateSelector = NSSelectorFromString(@"_updateRingerState:withVisuals:updatePreferenceRegister:");
    if (!application || ![application respondsToSelector:updateSelector]) {
        HBLogError(@"Unable to reset ringer state for action %@ because SpringBoard does not support %@",
                   listenerName ?: @"", NSStringFromSelector(updateSelector));
        return NO;
    }

    int ringerState = getRingerState();
    void (*updateRingerState)(id, SEL, int, BOOL, BOOL) =
        (void (*)(id, SEL, int, BOOL, BOOL))[application methodForSelector:updateSelector];
    updateRingerState(application, updateSelector, ringerState, YES, NO);
    return YES;
}

@end

@implementation LATRingerMuteController

- (BOOL)applyCommand:(LATRingerActionCommand *)command {
#if LA_TESTING
    LATTestingLastActionListenerName = [command.listenerName copy];
    LATTestingLastActionPhase = [command.testingPhase copy];
    if (LATTestingActionHandler) {
        return LATTestingActionHandler(command.listenerName ?: @"", command.testingPhase ?: @"");
    }
#endif

    if (![NSThread isMainThread]) {
        __block BOOL applied = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            applied = [self applyCommand:command];
        });
        return applied;
    }

    id ringerControl = [LATRingerActionListener ringerControlInstance];
    if (!ringerControl) {
        HBLogError(@"Unable to apply ringer action %@ because SBRingerControl was not captured",
                   command.listenerName ?: @"");
        return NO;
    }

    SEL setMutedSelector = NSSelectorFromString(@"setRingerMuted:");
    if (![ringerControl respondsToSelector:setMutedSelector]) {
        HBLogError(@"SBRingerControl does not support setRingerMuted:");
        return NO;
    }

    BOOL muted = NO;
    if (command.kind == LATRingerActionKindToggle) {
        SEL isMutedSelector = NSSelectorFromString(@"isRingerMuted");
        if (![ringerControl respondsToSelector:isMutedSelector]) {
            HBLogError(@"SBRingerControl does not support isRingerMuted");
            return NO;
        }
        BOOL (*isMuted)(id, SEL) = (BOOL(*)(id, SEL))[ringerControl methodForSelector:isMutedSelector];
        muted = !isMuted(ringerControl, isMutedSelector);
    } else {
        muted = (command.kind == LATRingerActionKindMute);
    }

    void (*setMuted)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[ringerControl methodForSelector:setMutedSelector];
    setMuted(ringerControl, setMutedSelector, muted);

    SEL activateHUDSelector = NSSelectorFromString(@"activateRingerHUDFromMuteSwitch:");
    if ([ringerControl respondsToSelector:activateHUDSelector]) {
        void (*activateHUD)(id, SEL, int) =
            (void (*)(id, SEL, int))[ringerControl methodForSelector:activateHUDSelector];
        activateHUD(ringerControl, activateHUDSelector, muted ? 0 : 1);
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

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Ringer action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    BOOL applied = NO;
    switch (command.kind) {
    case LATRingerActionKindReset:
        applied = [_stateResetter resetRingerStateForListenerName:listenerName testingPhase:command.testingPhase];
        break;
    case LATRingerActionKindMute:
    case LATRingerActionKindUnmute:
    case LATRingerActionKindToggle:
        applied = [_muteController applyCommand:command];
        break;
    }
    if (applied) {
        event.handled = YES;
    }
}

- (BOOL)listenerSelectorMatchesCommand:(LATRingerActionCommand *)command activator:(LAActivator *)activator {
#if LA_TESTING
    NSString *testingSelector = LATTestingSelectors[command.listenerName];
    if (testingSelector) {
        return [testingSelector isEqualToString:command.selectorName];
    }
#endif

    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATRingerActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATRingerActionCommand *> *commands;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<LATRingerActionCommand *> *commandList = @[
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.reset-ringer-state"
                                                    selectorName:@"resetRingerState"
                                                    testingPhase:@"ringer-reset"
                                                            kind:LATRingerActionKindReset],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.mute-ringer"
                                                    selectorName:@"muteRinger"
                                                    testingPhase:@"ringer-mute"
                                                            kind:LATRingerActionKindMute],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.unmute-ringer"
                                                    selectorName:@"unmuteRinger"
                                                    testingPhase:@"ringer-unmute"
                                                            kind:LATRingerActionKindUnmute],
            [[LATRingerActionCommand alloc] initWithListenerName:@"libactivator.audio.toggle-ringer-mute"
                                                    selectorName:@"toggleRingerMute"
                                                    testingPhase:@"ringer-toggle"
                                                            kind:LATRingerActionKindToggle],
        ];

        NSMutableDictionary<NSString *, LATRingerActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATRingerActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        commands = [mutableCommands copy];
    });
    return commands;
}

+ (void)noteRingerControlInstance:(id)ringerControl {
    if (ringerControl) {
        LATCapturedRingerControl = ringerControl;
    }
}

+ (id)ringerControlInstance {
    return LATCapturedRingerControl;
}

#if LA_TESTING
+ (void)setTestingActionHandler:(LATRingerActionHandler)handler {
    LATTestingActionHandler = [handler copy];
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

+ (NSString *)testingLastActionListenerName {
    return LATTestingLastActionListenerName;
}

+ (NSString *)testingLastActionPhase {
    return LATTestingLastActionPhase;
}

+ (void)resetTestingState {
    LATTestingActionHandler = nil;
    LATTestingLastActionListenerName = nil;
    LATTestingLastActionPhase = nil;
    [LATTestingSelectors removeAllObjects];
}
#endif

@end
