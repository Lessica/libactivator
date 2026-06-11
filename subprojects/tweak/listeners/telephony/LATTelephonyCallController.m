//
//  LATTelephonyCallController.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "telephony/LATTelephonyCallController.h"

#import "CTCall.h"
#import "telephony/LATTelephonyCallStateObserver.h"

#import <CoreFoundation/CoreFoundation.h>
#import <HBLog.h>

@interface LATTelephonyCallController ()
@property(nonatomic, strong, readwrite) LATTelephonyCallStateObserver *callStateObserver;
@end

@implementation LATTelephonyCallController

- (instancetype)init {
    self = [super init];
    if (self) {
        _callStateObserver = [[LATTelephonyCallStateObserver alloc] init];
    }
    return self;
}

- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self answerIncomingCallOnMainForListenerName:listenerName];
    });
    return YES;
}

- (BOOL)answerIncomingCallOnMainForListenerName:(NSString *)listenerName {
    int callCount = CTGetCurrentCallCount();
    HBLogInfo(@"Telephony action %@ detected %d current calls", listenerName ?: @"", callCount);
    if (callCount <= 0) {
        HBLogWarn(@"No calls detected while handling telephony action %@", listenerName ?: @"");
        return NO;
    }

    NSArray *calls = [self currentCallsForListenerName:listenerName];
    BOOL answered = NO;
    for (id callObject in calls) {
        CTCallRef call = (__bridge CTCallRef)callObject;
        CTCallStatus callStatus = CTCallGetStatus(call);
        NSString *callType = (__bridge NSString *)CTCallGetCallType(call);
        NSString *callAddress = CFBridgingRelease(CTCallCopyAddress(kCFAllocatorDefault, call));
        HBLogInfo(@"Telephony action %@ inspecting call status=%ld type=%@ address=%@", listenerName ?: @"",
                  (long)callStatus, callType ?: @"", callAddress ?: @"");
        if (callStatus == kCTCallStatusIncomingCall) {
            CTCallAnswer(call);
            answered = YES;
            HBLogInfo(@"Telephony action %@ requested answer for incoming call %@", listenerName ?: @"",
                      callAddress ?: @"");
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
    HBLogInfo(@"Telephony action %@ detected %d current calls", listenerName ?: @"", callCount);
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
    HBLogInfo(@"Telephony action %@ copied %lu current call objects", listenerName ?: @"", (unsigned long)calls.count);
    return calls;
}

@end
