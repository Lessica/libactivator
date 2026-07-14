//
//  LARemoteListener.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LARemoteListener.h"

#import "LAIPC.h"
#import "LAIPCCodec.h"
#import "LAResourceManager.h"

#import <dispatch/dispatch.h>
#import <math.h>

@interface LARemoteListener ()
@property(nonatomic, strong) LAIPCClient *ipcClient;
@end

@implementation LARemoteListener

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _ipcClient = [[LAIPCClient alloc] init];
    }
    return self;
}

#pragma mark - Event Delivery

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self.ipcClient sendEventMessageName:LAIPCMessageRemoteListenerReceiveEvent
                                userInfo:[LAIPCCodec userInfoWithEvent:event listenerName:listenerName]
                                   event:event];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self.ipcClient sendEventMessageName:LAIPCMessageRemoteListenerAbortEvent
                                userInfo:[LAIPCCodec userInfoWithEvent:event listenerName:listenerName]
                                   event:event];
}

#pragma mark - Metadata

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedTitleForListenerName userInfo:userInfo];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedDescriptionForListenerName userInfo:userInfo];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedGroupForListenerName userInfo:userInfo];
}

- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    BOOL value = [self.ipcClient boolValueForMessageName:LAIPCMessageListenerRequiresAssignment
                                                userInfo:userInfo
                                            defaultValue:NO];
    return @(value);
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient arrayValueForMessageName:LAIPCMessageCompatibleModesForListener userInfo:userInfo];
}

- (NSNumber *)activator:(LAActivator *)activator
    requiresIsCompatibleWithEventName:(NSString *)eventName
                         listenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{
        LAIPCKeyListenerName : listenerName ?: @"",
        LAIPCKeyEventName : eventName ?: @"",
    };
    BOOL value = [self.ipcClient boolValueForMessageName:LAIPCMessageListenerIsCompatibleWithEvent
                                                userInfo:userInfo
                                            defaultValue:NO];
    return @(value);
}

- (NSArray *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient arrayValueForMessageName:LAIPCMessageExclusiveAssignmentGroupsForListener userInfo:userInfo];
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    NSDictionary *userInfo = @{
        LAIPCKeyInfoDictionaryKey : key ?: @"",
        LAIPCKeyListenerName : listenerName ?: @"",
    };
    return [self.ipcClient propertyListValueForMessageName:LAIPCMessageListenerInfoDictionaryValue userInfo:userInfo];
}

- (BOOL)activator:(LAActivator *)activator requiresNeedsPoweredDisplayForListenerName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerNeedsPoweredDisplay
                                          userInfo:userInfo
                                      defaultValue:NO];
}

#pragma mark - Icons

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName {
    CGFloat scale = 1.0f;
    return [self dataValueForMessageName:LAIPCMessageListenerSmallIconData listenerName:listenerName scale:&scale];
}

- (NSData *)activator:(LAActivator *)activator
    requiresSmallIconDataForListenerName:(NSString *)listenerName
                                   scale:(CGFloat *)scale {
    return [self dataValueForMessageName:LAIPCMessageListenerSmallIconData listenerName:listenerName scale:scale];
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
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerSupportsRemoval
                                          userInfo:userInfo
                                      defaultValue:NO];
}

- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName {
    NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
    [self.ipcClient sendMessageName:LAIPCMessageRequestListenerRemoval userInfo:userInfo];
}

- (CGFloat)scaleInReply:(NSDictionary *)reply defaultScale:(CGFloat)defaultScale {
    id value = reply[LAIPCKeyScale];
    CGFloat scale = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : defaultScale;
    return isfinite((double)scale) && scale > 0.0 ? scale : defaultScale;
}

- (NSData *)dataValueForMessageName:(NSString *)messageName
                       listenerName:(NSString *)listenerName
                              scale:(CGFloat *)scale {
    CGFloat requestedScale = scale ? *scale : UIScreen.mainScreen.scale;
    BOOL smallIcon = [messageName isEqualToString:LAIPCMessageListenerSmallIconData];
    NSData *localData = [LAResourceManager.sharedManager iconDataForListenerName:listenerName
                                                                           small:smallIcon
                                                                           scale:scale];
    if (localData.length > 0) {
        return localData;
    }

    if (!isfinite((double)requestedScale) || requestedScale <= 0.0) {
        requestedScale = UIScreen.mainScreen.scale;
    }

    NSDictionary *userInfo = @{
        LAIPCKeyListenerName : listenerName ?: @"",
        LAIPCKeyScale : @(requestedScale),
    };
    NSDictionary *reply = [self.ipcClient replyForMessageName:messageName userInfo:userInfo];
    id value = reply[LAIPCKeyValue];
    if (![value isKindOfClass:NSData.class]) {
        return nil;
    }
    if (scale) {
        *scale = [self scaleInReply:reply defaultScale:requestedScale];
    }
    return [value copy];
}

@end
