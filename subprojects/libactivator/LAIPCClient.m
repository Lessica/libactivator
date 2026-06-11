//
//  LAIPCClient.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAIPC.h"
#import "LAIPCCodec.h"

#import <Activator/Activator.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAIPCClient ()
@property(nonatomic, strong) CPDistributedMessagingCenter *center;
@end

@implementation LAIPCClient

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LAIPCServerName];
    }
    return self;
}

#pragma mark - Requests

- (NSDictionary *)replyForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSDictionary *reply = [self.center sendMessageAndReceiveReplyName:messageName userInfo:userInfo ?: @{}];
    if (![reply isKindOfClass:NSDictionary.class] || ![reply[LAIPCKeyOK] boolValue]) {
        return nil;
    }
    return reply;
}

- (NSArray *)arrayValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAIPCKeyValue];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (NSString *)stringValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAIPCKeyValue];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

- (id)propertyListValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self replyForMessageName:messageName userInfo:userInfo][LAIPCKeyValue];
}

- (BOOL)boolValueForMessageName:(NSString *)messageName
                       userInfo:(NSDictionary *)userInfo
                   defaultValue:(BOOL)defaultValue {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAIPCKeyValue];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : defaultValue;
}

- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [LAIPCCodec eventsWithDictionaries:[self arrayValueForMessageName:messageName userInfo:userInfo]];
}

- (BOOL)sendEventMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo event:(LAEvent *)event {
    NSDictionary *reply = [self replyForMessageName:messageName userInfo:userInfo];
    if (!reply) {
        return NO;
    }

    id handled = reply[LAIPCKeyEventHandled];
    if ([handled isKindOfClass:NSNumber.class]) {
        event.handled = [handled boolValue];
    }
    return YES;
}

- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self replyForMessageName:messageName userInfo:userInfo] != nil;
}

@end
