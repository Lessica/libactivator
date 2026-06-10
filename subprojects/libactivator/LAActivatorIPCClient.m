//
//  LAActivatorIPCClient.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorIPC.h"
#import "LAActivatorIPCCodec.h"

#import <Activator/Activator.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAActivatorIPCClient ()
@property(nonatomic, strong) CPDistributedMessagingCenter *center;
@end

@implementation LAActivatorIPCClient

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LAActivatorIPCServerName];
    }
    return self;
}

#pragma mark - Requests

- (NSDictionary *)replyForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    NSDictionary *reply = [self.center sendMessageAndReceiveReplyName:messageName userInfo:userInfo ?: @{}];
    if (![reply isKindOfClass:NSDictionary.class] || ![reply[LAActivatorIPCKeyOK] boolValue]) {
        return nil;
    }
    return reply;
}

- (NSArray *)arrayValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (NSString *)stringValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

- (id)propertyListValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
}

- (BOOL)boolValueForMessageName:(NSString *)messageName
                       userInfo:(NSDictionary *)userInfo
                   defaultValue:(BOOL)defaultValue {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : defaultValue;
}

- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [LAActivatorIPCCodec eventsWithDictionaries:[self arrayValueForMessageName:messageName userInfo:userInfo]];
}

- (BOOL)sendEventMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo event:(LAEvent *)event {
    NSDictionary *reply = [self replyForMessageName:messageName userInfo:userInfo];
    if (!reply) {
        return NO;
    }

    id handled = reply[LAActivatorIPCKeyEventHandled];
    if ([handled isKindOfClass:NSNumber.class]) {
        event.handled = [handled boolValue];
    }
    return YES;
}

- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self replyForMessageName:messageName userInfo:userInfo] != nil;
}

@end
