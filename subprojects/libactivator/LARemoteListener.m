//
//  LARemoteListener.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LARemoteListener.h"

#import "LAActivatorIPC.h"
#import "LAActivatorResourceManager.h"

#import <dispatch/dispatch.h>

@interface LARemoteListener ()
@property(nonatomic, strong) LAActivatorIPCClient *ipcClient;
- (NSDictionary *)userInfoForEvent:(LAEvent *)event listenerName:(NSString *)listenerName;
- (CGFloat)scaleInReply:(NSDictionary *)reply defaultScale:(CGFloat)defaultScale;
- (NSData *)dataValueForMessageName:(NSString *)messageName
                       listenerName:(NSString *)listenerName
                              scale:(CGFloat *)scale;
@end

@implementation LARemoteListener

#pragma mark - Lifecycle

+ (instancetype)sharedListener {
    static dispatch_once_t onceToken;
    static LARemoteListener *listener;
    dispatch_once(&onceToken, ^{
        listener = [[self alloc] init];
    });
    return listener;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ipcClient = [[LAActivatorIPCClient alloc] init];
    }
    return self;
}

#pragma mark - Event Delivery

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self.ipcClient sendEventMessageName:LAActivatorIPCMessageRemoteListenerReceiveEvent
                                userInfo:[self userInfoForEvent:event listenerName:listenerName]
                                   event:event];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self.ipcClient sendEventMessageName:LAActivatorIPCMessageRemoteListenerAbortEvent
                                userInfo:[self userInfoForEvent:event listenerName:listenerName]
                                   event:event];
}

#pragma mark - Metadata

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedTitleForListenerName
                                            userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedDescriptionForListenerName
                                            userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedGroupForListenerName
                                            userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName {
    BOOL value = [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerRequiresAssignment
                                                userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}
                                            defaultValue:NO];
    return @(value);
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageCompatibleModesForListener
                                           userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

- (NSNumber *)activator:(LAActivator *)activator
    requiresIsCompatibleWithEventName:(NSString *)eventName
                         listenerName:(NSString *)listenerName {
    BOOL value = [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerIsCompatibleWithEvent
                                                userInfo:@{
                                                    LAActivatorIPCKeyListenerName : listenerName ?: @"",
                                                    LAActivatorIPCKeyEventName : eventName ?: @"",
                                                }
                                            defaultValue:NO];
    return @(value);
}

- (NSArray *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageExclusiveAssignmentGroupsForListener
                                           userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    return [self.ipcClient propertyListValueForMessageName:LAActivatorIPCMessageListenerInfoDictionaryValue
                                                  userInfo:@{
                                                      LAActivatorIPCKeyInfoDictionaryKey : key ?: @"",
                                                      LAActivatorIPCKeyListenerName : listenerName ?: @"",
                                                  }];
}

- (BOOL)activator:(LAActivator *)activator requiresNeedsPoweredDisplayForListenerName:(NSString *)listenerName {
    return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerNeedsPoweredDisplay
                                          userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}
                                      defaultValue:NO];
}

#pragma mark - Icons

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName {
    CGFloat scale = 1.0f;
    return [self dataValueForMessageName:LAActivatorIPCMessageListenerIconData listenerName:listenerName scale:&scale];
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName {
    CGFloat scale = 1.0f;
    return [self dataValueForMessageName:LAActivatorIPCMessageListenerSmallIconData
                            listenerName:listenerName
                                   scale:&scale];
}

- (NSData *)activator:(LAActivator *)activator
    requiresIconDataForListenerName:(NSString *)listenerName
                              scale:(CGFloat *)scale {
    return [self dataValueForMessageName:LAActivatorIPCMessageListenerIconData listenerName:listenerName scale:scale];
}

- (NSData *)activator:(LAActivator *)activator
    requiresSmallIconDataForListenerName:(NSString *)listenerName
                                   scale:(CGFloat *)scale {
    return [self dataValueForMessageName:LAActivatorIPCMessageListenerSmallIconData
                            listenerName:listenerName
                                   scale:scale];
}

- (UIImage *)activator:(LAActivator *)activator
    requiresIconForListenerName:(NSString *)listenerName
                          scale:(CGFloat)scale {
    CGFloat actualScale = scale;
    NSData *data = [self activator:activator requiresIconDataForListenerName:listenerName scale:&actualScale];
    return data.length > 0 ? [UIImage imageWithData:data scale:actualScale > 0.0f ? actualScale : 1.0f] : nil;
}

- (UIImage *)activator:(LAActivator *)activator
    requiresSmallIconForListenerName:(NSString *)listenerName
                               scale:(CGFloat)scale {
    CGFloat actualScale = scale;
    NSData *data = [self activator:activator requiresSmallIconDataForListenerName:listenerName scale:&actualScale];
    return data.length > 0 ? [UIImage imageWithData:data scale:actualScale > 0.0f ? actualScale : 1.0f] : nil;
}

#pragma mark - Removal

- (BOOL)activator:(LAActivator *)activator requiresSupportsRemovalForListenerWithName:(NSString *)listenerName {
    return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerSupportsRemoval
                                          userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}
                                      defaultValue:NO];
}

- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName {
    [self.ipcClient sendMessageName:LAActivatorIPCMessageRequestListenerRemoval
                           userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
}

#pragma mark - Serialization

- (NSDictionary *)userInfoForEvent:(LAEvent *)event listenerName:(NSString *)listenerName {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{
        LAActivatorIPCKeyEventName : event.name,
        LAActivatorIPCKeyEventHandled : @(event.handled),
        LAActivatorIPCKeyListenerName : listenerName ?: @"",
    } mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAActivatorIPCKeyEventMode] = event.mode;
    }
    if ([event.userInfo isKindOfClass:NSDictionary.class] &&
        [NSPropertyListSerialization propertyList:event.userInfo isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        userInfo[LAActivatorIPCKeyEventUserInfo] = event.userInfo;
    }
    return [userInfo copy];
}

- (CGFloat)scaleInReply:(NSDictionary *)reply defaultScale:(CGFloat)defaultScale {
    id value = reply[LAActivatorIPCKeyScale];
    return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : defaultScale;
}

- (NSData *)dataValueForMessageName:(NSString *)messageName
                       listenerName:(NSString *)listenerName
                              scale:(CGFloat *)scale {
    CGFloat requestedScale = scale ? *scale : UIScreen.mainScreen.scale;
    BOOL smallIcon = [messageName isEqualToString:LAActivatorIPCMessageListenerSmallIconData];
    NSData *localData = [LAActivatorResourceManager.sharedManager iconDataForListenerName:listenerName
                                                                                    small:smallIcon
                                                                                    scale:scale];
    if (localData.length > 0) {
        return localData;
    }

    NSDictionary *reply = [self.ipcClient replyForMessageName:messageName
                                                     userInfo:@{
                                                         LAActivatorIPCKeyListenerName : listenerName ?: @"",
                                                         LAActivatorIPCKeyScale : @(requestedScale),
                                                     }];
    id value = reply[LAActivatorIPCKeyValue];
    if (![value isKindOfClass:NSData.class]) {
        return nil;
    }
    if (scale) {
        *scale = [self scaleInReply:reply defaultScale:requestedScale];
    }
    return value;
}

@end
