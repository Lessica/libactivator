//
//  LATPhoneActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATPhoneActionListener.h"

#import "CTCall.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options error:(NSError **)error;
@end

typedef NS_ENUM(NSUInteger, LATPhoneActionKind) {
    LATPhoneActionKindOpenURL,
    LATPhoneActionKindAnswerCall,
    LATPhoneActionKindDisconnectCall,
};

@interface LATPhoneActionCommand : NSObject
@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATPhoneActionKind kind;
@property(nonatomic, copy, readonly, nullable) NSString *URLString;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                           URLString:(nullable NSString *)URLString;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATPhoneActionKind)kind;
@end

@interface LATPhoneURLActionOpener : NSObject
- (BOOL)openURLString:(NSString *)URLString listenerName:(NSString *)listenerName;
@end

@interface LATPhoneCallController : NSObject
- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName;
- (BOOL)disconnectCallsForListenerName:(NSString *)listenerName;
@end

@implementation LATPhoneActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                           URLString:(NSString *)URLString {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATPhoneActionKindOpenURL;
        _URLString = [URLString copy];
    }
    return self;
}

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATPhoneActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = kind;
        _URLString = nil;
    }
    return self;
}

@end

@implementation LATPhoneURLActionOpener

- (BOOL)openURLString:(NSString *)URLString listenerName:(NSString *)listenerName {
    NSURL *URL = [NSURL URLWithString:URLString ?: @""];
    if (URL.scheme.length == 0) {
        HBLogWarn(@"Phone action %@ has invalid URL %@", listenerName ?: @"", URLString ?: @"");
        return NO;
    }

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        HBLogError(@"LSApplicationWorkspace is unavailable");
        return NO;
    }

    LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
    if (![workspace respondsToSelector:@selector(openSensitiveURL:withOptions:error:)]) {
        HBLogError(@"LSApplicationWorkspace does not support openSensitiveURL:withOptions:error:");
        return NO;
    }

    dispatch_async([self.class openQueue], ^{
        NSError *error = nil;
        BOOL opened = [workspace openSensitiveURL:URL withOptions:@{} error:&error];
        if (!opened) {
            HBLogError(@"Failed to open phone action %@ URL %@: %@", listenerName ?: @"", URL.absoluteString ?: @"",
                       error.localizedDescription ?: @"unknown error");
        }
    });
    return YES;
}

+ (dispatch_queue_t)openQueue {
    static dispatch_queue_t sQueue;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        sQueue = dispatch_queue_create("com.libactivator.phone-actions.open", DISPATCH_QUEUE_SERIAL);
    });
    return sQueue;
}

@end

@implementation LATPhoneCallController

- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self answerIncomingCallOnMainForListenerName:listenerName];
    });
    return YES;
}

- (BOOL)answerIncomingCallOnMainForListenerName:(NSString *)listenerName {
    int callCount = CTGetCurrentCallCount();
    if (callCount <= 0) {
        HBLogWarn(@"No calls detected while handling phone action %@", listenerName ?: @"");
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
        HBLogWarn(@"No incoming call was available for phone action %@", listenerName ?: @"");
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
        HBLogWarn(@"No calls detected while handling phone action %@", listenerName ?: @"");
        return NO;
    }

    CTCallListDisconnectAll();
    return YES;
}

- (NSArray *)currentCallsForListenerName:(NSString *)listenerName {
    CFArrayRef currentCalls = CTCopyCurrentCalls(kCFAllocatorDefault);
    NSArray *calls = currentCalls ? CFBridgingRelease(currentCalls) : nil;
    if (![calls isKindOfClass:NSArray.class]) {
        HBLogError(@"Unable to copy current calls for phone action %@", listenerName ?: @"");
        return @[];
    }
    return calls;
}

@end

@implementation LATPhoneActionListener {
    LATPhoneURLActionOpener *_opener;
    LATPhoneCallController *_callController;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _opener = [[LATPhoneURLActionOpener alloc] init];
        _callController = [[LATPhoneCallController alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return [[self commandsByListenerName] allKeys];
}

+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName {
    LATPhoneActionCommand *command = [self commandsByListenerName][listenerName ?: @""];
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
    LATPhoneActionCommand *command = [self.class commandsByListenerName][listenerName ?: @""];
    if (!command) {
        HBLogWarn(@"Phone action %@ has no command mapping", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    if (![self listenerSelectorMatchesCommand:command activator:activator]) {
        HBLogWarn(@"Phone action %@ metadata selector does not match %@", listenerName ?: @"", command.selectorName);
        return;
    }

    switch (command.kind) {
    case LATPhoneActionKindOpenURL:
        [_opener openURLString:command.URLString listenerName:listenerName];
        break;
    case LATPhoneActionKindAnswerCall:
        [_callController answerIncomingCallForListenerName:listenerName];
        break;
    case LATPhoneActionKindDisconnectCall:
        [_callController disconnectCallsForListenerName:listenerName];
        break;
    }
}

- (BOOL)listenerSelectorMatchesCommand:(LATPhoneActionCommand *)command activator:(LAActivator *)activator {
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:command.listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:command.selectorName];
}

+ (NSDictionary<NSString *, LATPhoneActionCommand *> *)commandsByListenerName {
    static NSDictionary<NSString *, LATPhoneActionCommand *> *sCommands;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        NSArray<LATPhoneActionCommand *> *commandList = @[
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.answer-call"
                                                   selectorName:@"answerCall"
                                                           kind:LATPhoneActionKindAnswerCall],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.disconnect-call"
                                                   selectorName:@"answerCall"
                                                           kind:LATPhoneActionKindDisconnectCall],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.favorites"
                                                   selectorName:@"showPhoneFavorites"
                                                      URLString:@"mobilephone-favorites:"],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.recents"
                                                   selectorName:@"showPhoneRecents"
                                                      URLString:@"mobilephone-recents:"],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.contacts"
                                                   selectorName:@"showPhoneContacts"
                                                      URLString:@"mobilephone-contacts:"],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.keypad"
                                                   selectorName:@"showPhoneKeypad"
                                                      URLString:@"mobilephone-keypad:"],
            [[LATPhoneActionCommand alloc] initWithListenerName:@"libactivator.phone.voicemail"
                                                   selectorName:@"showPhoneVoicemail"
                                                      URLString:@"vmshow:"],
        ];

        NSMutableDictionary<NSString *, LATPhoneActionCommand *> *mutableCommands =
            [[NSMutableDictionary alloc] initWithCapacity:commandList.count];
        for (LATPhoneActionCommand *command in commandList) {
            mutableCommands[command.listenerName] = command;
        }
        sCommands = [mutableCommands copy];
    });
    return sCommands;
}

@end
