#import "LAActivatorIPC.h"

#import <Activator/Activator.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAActivatorIPCClient ()
+ (NSString *)la_stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (LAEvent *)la_eventWithUserInfo:(NSDictionary *)userInfo;
+ (NSArray *)la_eventsWithDictionaries:(NSArray *)eventDictionaries;
@end

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

- (BOOL)boolValueForMessageName:(NSString *)messageName
                       userInfo:(NSDictionary *)userInfo
                   defaultValue:(BOOL)defaultValue {
    id value = [self replyForMessageName:messageName userInfo:userInfo][LAActivatorIPCKeyValue];
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : defaultValue;
}

- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [[self class] la_eventsWithDictionaries:[self arrayValueForMessageName:messageName userInfo:userInfo]];
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

#pragma mark - Serialization

+ (NSString *)la_stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

+ (LAEvent *)la_eventWithUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [self la_stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    if (eventName.length == 0) {
        return nil;
    }
    return [LAEvent eventWithName:eventName mode:[self la_stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventMode]];
}

+ (NSArray *)la_eventsWithDictionaries:(NSArray *)eventDictionaries {
    if (![eventDictionaries isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray arrayWithCapacity:eventDictionaries.count];
    for (id dictionary in eventDictionaries) {
        if (![dictionary isKindOfClass:NSDictionary.class]) {
            continue;
        }
        LAEvent *event = [self la_eventWithUserInfo:dictionary];
        if (event) {
            [events addObject:event];
        }
    }
    return [events copy];
}

@end
