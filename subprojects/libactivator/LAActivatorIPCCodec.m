//
//  LAActivatorIPCCodec.m
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorIPCCodec.h"

#import "LAActivatorIPC.h"

#import <Activator/Activator.h>

@implementation LAActivatorIPCCodec

+ (NSDictionary *)replyWithOK:(BOOL)ok value:(id)value {
    if (value) {
        return @{LAActivatorIPCKeyOK : @(ok), LAActivatorIPCKeyValue : value};
    }
    return @{LAActivatorIPCKeyOK : @(ok)};
}

+ (NSDictionary *)eventReplyWithEvent:(LAEvent *)event {
    return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyEventHandled : @([event isHandled])};
}

+ (NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

+ (NSArray *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:[value count]];
    for (id item in value) {
        if ([item isKindOfClass:NSString.class] && [item length] > 0 && ![strings containsObject:item]) {
            [strings addObject:item];
        }
    }
    return [[strings sortedArrayUsingSelector:@selector(compare:)] copy];
}

+ (NSArray *)uniqueOrderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:[value count]];
    NSMutableSet *seenStrings = [NSMutableSet set];
    for (id item in value) {
        if ([item isKindOfClass:NSString.class] && [item length] > 0 && ![seenStrings containsObject:item]) {
            [seenStrings addObject:item];
            [strings addObject:item];
        }
    }
    return [strings copy];
}

+ (LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    if (eventName.length == 0) {
        return nil;
    }

    LAEvent *event = [LAEvent eventWithName:eventName
                                       mode:[self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventMode]];
    event.handled = [userInfo[LAActivatorIPCKeyEventHandled] boolValue];

    id eventUserInfo = userInfo[LAActivatorIPCKeyEventUserInfo];
    if ([eventUserInfo isKindOfClass:NSDictionary.class]) {
        event.userInfo = eventUserInfo;
    }
    return event;
}

+ (NSDictionary *)userInfoWithEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAActivatorIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAActivatorIPCKeyEventMode] = event.mode;
    }
    return [userInfo copy];
}

+ (NSArray *)eventDictionariesWithEvents:(NSArray *)events {
    NSMutableArray *dictionaries = [NSMutableArray arrayWithCapacity:events.count];
    for (LAEvent *event in events) {
        if ([event isKindOfClass:LAEvent.class] && event.name.length > 0) {
            [dictionaries addObject:[self userInfoWithEvent:event]];
        }
    }
    return [dictionaries copy];
}

+ (NSArray *)eventsWithDictionaries:(NSArray *)eventDictionaries {
    if (![eventDictionaries isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray arrayWithCapacity:eventDictionaries.count];
    for (id dictionary in eventDictionaries) {
        if (![dictionary isKindOfClass:NSDictionary.class]) {
            continue;
        }
        LAEvent *event = [self eventWithUserInfo:dictionary];
        if (event) {
            [events addObject:event];
        }
    }
    return [events copy];
}

+ (id)propertyListValue:(id)value {
    if (!value) {
        return nil;
    }
    return [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0] ? value
                                                                                                             : nil;
}

+ (NSDictionary *)smallIconDataReplyWithData:(NSData *)data scale:(CGFloat)scale {
    if (data.length == 0) {
        return [self replyWithOK:NO value:nil];
    }
    return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyValue : data, LAActivatorIPCKeyScale : @(scale)};
}

@end
