//
//  LATTelephonyActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATTelephonyActionListener.h"

#import "CTCall.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, LATTelephonyActionKind) {
    LATTelephonyActionKindAnswerCall,
    LATTelephonyActionKindDisconnectCall,
};

@interface LATTelephonyActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATTelephonyActionKind kind;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATTelephonyActionKind)kind;
@end

@interface LATTelephonyCallController : NSObject
- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName;
- (BOOL)disconnectCallsForListenerName:(NSString *)listenerName;
@end

@interface LATTelephonyActionListener ()
@property(nonatomic, strong) LATTelephonyCallController *callController;
@end

@implementation LATTelephonyActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATTelephonyActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = kind;
    }
    return self;
}

@end

@implementation LATTelephonyCallController

- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self answerIncomingCallOnMainForListenerName:listenerName];
    });
    return YES;
}

- (BOOL)answerIncomingCallOnMainForListenerName:(NSString *)listenerName {
    int callCount = CTGetCurrentCallCount();
    if (callCount <= 0) {
        HBLogWarn(@"No calls detected while handling telephony action %@", listenerName ?: @"");
        return NO;
    }

    NSArray *calls = [self currentCallsForListenerName:listenerName];
    BOOL answered = NO;
    for (id callObject in calls) {
        CTCallRef call = (__bridge CTCallRef)callObject;
        if (CTCallGetStatus(call) == kCTCallStatusIncomingCall) {
            CTCallAnswer(call);
            answered = YES;
        }
    }

    if (!answered) {
        HBLogWarn(@"No incoming call was available for telephony action %@", listenerName ?: @"");
    }
    return answered;
}

- (BOOL)disconnectCallsForListenerName:(NSString *)listenerName {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self disconnectCallsOnMainForListenerName:listenerName];
    });
    return YES;
}

- (BOOL)disconnectCallsOnMainForListenerName:(NSString *)listenerName {
    int callCount = CTGetCurrentCallCount();
    if (callCount <= 0) {
        HBLogWarn(@"No calls detected while handling telephony action %@", listenerName ?: @"");
        return NO;
    }

    CTCallListDisconnectAll();
    return YES;
}

- (NSArray *)currentCallsForListenerName:(NSString *)listenerName {
    CFArrayRef currentCalls = CTCopyCurrentCalls(kCFAllocatorDefault);
    NSArray *calls = currentCalls ? CFBridgingRelease(currentCalls) : nil;
    if (![calls isKindOfClass:NSArray.class]) {
        HBLogError(@"Unable to copy current calls for telephony action %@", listenerName ?: @"");
        return @[];
    }
    return calls;
}

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

    event.handled = YES;

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Telephony action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    switch (command.kind) {
    case LATTelephonyActionKindAnswerCall:
        [self.callController answerIncomingCallForListenerName:listenerName];
        break;
    case LATTelephonyActionKindDisconnectCall:
        [self.callController disconnectCallsForListenerName:listenerName];
        break;
    }
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
                                                       selectorName:@"answerCall"
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
