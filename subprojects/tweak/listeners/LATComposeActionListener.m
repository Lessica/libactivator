//
//  LATComposeActionListener.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATComposeActionListener.h"

#import "compose/LATComposeActionCommand.h"
#import "compose/LATComposeActionPresenter.h"

#import <HBLog.h>

@interface LATComposeActionListener ()
@property(nonatomic, strong) LATComposeActionPresenter *presenter;
@end

@implementation LATComposeActionListener

- (instancetype)initWithBuiltInListenerContext:(__unused LATBuiltInListenerContext *)context {
    return [self init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _presenter = [[LATComposeActionPresenter alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATComposeActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATComposeActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Compose action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    if (![self shouldHandleListenerName:listenerName activator:activator]) {
        HBLogWarn(@"Compose action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    event.handled = [self.presenter performComposeAction:command.kind listenerName:listenerName];
}

- (BOOL)shouldHandleListenerName:(NSString *)listenerName activator:(LAActivator *)activator {
    LATComposeActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        return NO;
    }
    return [self listenerSelectorMatchesCommand:command activator:activator];
}

- (BOOL)listenerSelectorMatchesCommand:(LATComposeActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATComposeActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATComposeActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATComposeActionCommand *> *commandList = @[
            [[LATComposeActionCommand alloc] initWithListenerName:@"libactivator.mail.compose-message"
                                                     selectorName:@"composeMail"
                                                             kind:LATComposeActionKindMail],
            [[LATComposeActionCommand alloc] initWithListenerName:@"libactivator.sms.compose-message"
                                                     selectorName:@"composeText"
                                                             kind:LATComposeActionKindText],
            [[LATComposeActionCommand alloc] initWithListenerName:@"libactivator.notes.compose-note"
                                                     selectorName:@"composeNote"
                                                             kind:LATComposeActionKindNote],
        ];

        NSMutableDictionary<NSString *, LATComposeActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATComposeActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
