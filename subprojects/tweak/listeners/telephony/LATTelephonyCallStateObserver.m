//
//  LATTelephonyCallStateObserver.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "telephony/LATTelephonyCallStateObserver.h"

#import "CTCall.h"

#import <HBLog.h>

extern CFNotificationCenterRef CTTelephonyCenterGetDefault(void);
extern void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer,
                                         CFNotificationCallback callBack, CFStringRef name, const void *object,
                                         CFNotificationSuspensionBehavior suspensionBehavior);
extern void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name,
                                            const void *object);

static void LATTelephonyCallStateDidChange(__unused CFNotificationCenterRef center, void *observer, CFStringRef name,
                                           __unused const void *object, __unused CFDictionaryRef userInfo) {
    LATTelephonyCallStateObserver *callStateObserver = (__bridge LATTelephonyCallStateObserver *)observer;
    [callStateObserver telephonyCallStateDidChangeWithName:name];
}

@implementation LATTelephonyCallStateObserver

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastKnownCallCount = CTGetCurrentCallCount();
        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), (__bridge const void *)self,
                                     LATTelephonyCallStateDidChange, kCTCallStatusChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);
        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), (__bridge const void *)self,
                                     LATTelephonyCallStateDidChange, kCTCallIdentificationChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)dealloc {
    CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (__bridge const void *)self,
                                    kCTCallStatusChangeNotification, NULL);
    CTTelephonyCenterRemoveObserver(CTTelephonyCenterGetDefault(), (__bridge const void *)self,
                                    kCTCallIdentificationChangeNotification, NULL);
}

- (void)telephonyCallStateDidChangeWithName:(CFStringRef)name {
    _lastKnownCallCount = CTGetCurrentCallCount();
    HBLogInfo(@"Telephony call state changed: %@ call count = %d", (__bridge NSString *)name ?: @"",
              _lastKnownCallCount);
}

@end
