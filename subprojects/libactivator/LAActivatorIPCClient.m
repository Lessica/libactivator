#import "LAActivatorIPC.h"

#import <Activator/Activator.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

static NSString *LAIPCString(NSDictionary *userInfo, NSString *key) {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static LAEvent *LAIPCEvent(NSDictionary *userInfo) {
    NSString *eventName = LAIPCString(userInfo, LAActivatorIPCKeyEventName);
    if (eventName.length == 0) {
        return nil;
    }
    return [LAEvent eventWithName:eventName mode:LAIPCString(userInfo, LAActivatorIPCKeyEventMode)];
}

static NSArray *LAIPCEvents(NSArray *eventDictionaries) {
    if (![eventDictionaries isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray arrayWithCapacity:eventDictionaries.count];
    for (id dictionary in eventDictionaries) {
        if (![dictionary isKindOfClass:NSDictionary.class]) {
            continue;
        }
        LAEvent *event = LAIPCEvent(dictionary);
        if (event) {
            [events addObject:event];
        }
    }
    return [events copy];
}

@implementation LAActivatorIPCClient {
    CPDistributedMessagingCenter *_center;
}

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
    NSDictionary *reply = [_center sendMessageAndReceiveReplyName:messageName userInfo:userInfo ?: @{}];
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

- (BOOL)boolValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo defaultValue:(BOOL)defaultValue {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : defaultValue;
}

- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return LAIPCEvents([self arrayValueForMessageName:messageName userInfo:userInfo]);
}

- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self replyForMessageName:messageName userInfo:userInfo] != nil;
}

@end
