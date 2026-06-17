//
//  LATTelephonyActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATTelephonyActionListener.h"

#import "CTCall.h"
#import "telephony/LATTelephonyActionCommand.h"
#import "telephony/LATTelephonyCallController.h"

#import <HBLog.h>

@interface LATTelephonyActionListener ()
@property(nonatomic, strong) LATTelephonyCallController *callController;
@end

@implementation LATTelephonyActionListener

- (instancetype)init {
    self = [super init];
    if (self) {
        _callController = [[LATTelephonyCallController alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATTelephonyActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATTelephonyActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Telephony action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    if (![self shouldHandleListenerName:listenerName activator:activator]) {
        HBLogWarn(@"Telephony action %@ metadata selector does not match %@", listenerName ?: @"",
                  command.selectorName);
        return;
    }

    switch (command.kind) {
    case LATTelephonyActionKindAnswerCall:
        event.handled = [self.callController answerIncomingCallForListenerName:listenerName];
        break;
    case LATTelephonyActionKindDisconnectCall:
        event.handled = [self.callController disconnectCallsForListenerName:listenerName];
        break;
    }
}

- (BOOL)shouldHandleListenerName:(NSString *)listenerName activator:(LAActivator *)activator {
    LATTelephonyActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        return NO;
    }
    return [self listenerSelectorMatchesCommand:command activator:activator];
}

- (BOOL)listenerSelectorMatchesCommand:(LATTelephonyActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATTelephonyActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATTelephonyActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATTelephonyActionCommand *> *commandList = @[
            [[LATTelephonyActionCommand alloc] initWithListenerName:@"libactivator.phone.answer-call"
                                                       selectorName:@"answerCall"
                                                               kind:LATTelephonyActionKindAnswerCall],
            [[LATTelephonyActionCommand alloc] initWithListenerName:@"libactivator.phone.disconnect-call"
                                                       selectorName:@"disconnectCall"
                                                               kind:LATTelephonyActionKindDisconnectCall],
        ];

        NSMutableDictionary<NSString *, LATTelephonyActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATTelephonyActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
