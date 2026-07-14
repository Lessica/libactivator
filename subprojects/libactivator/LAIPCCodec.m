//
//  LAIPCCodec.m
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAIPCCodec.h"

#import "LAIPC.h"

#import <Activator/Activator.h>
#import <math.h>

static NSUInteger const LAIPCCodecMaximumPropertyListDepth = 32;

@implementation LAIPCCodec

+ (NSDictionary *)replyWithOK:(BOOL)ok value:(id)value {
    if (value) {
        return @{LAIPCKeyOK : @(ok), LAIPCKeyValue : value};
    }
    return @{LAIPCKeyOK : @(ok)};
}

+ (NSDictionary *)eventReplyWithEvent:(LAEvent *)event {
    return @{LAIPCKeyOK : @YES, LAIPCKeyEventHandled : @([event isHandled])};
}

+ (NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

+ (NSNumber *)numberInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    return [value isKindOfClass:NSNumber.class] ? value : nil;
}

+ (NSArray *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:[value count]];
    for (id item in value) {
        if ([item isKindOfClass:NSString.class] && [item length] > 0 && ![strings containsObject:item]) {
            [strings addObject:[item copy]];
        }
    }
    return [[strings sortedArrayUsingSelector:@selector(compare:)] copy];
}

+ (NSArray *)uniqueOrderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    return [self uniqueOrderedStringArray:userInfo[key]];
}

+ (NSArray *)uniqueOrderedStringArray:(NSArray *)array {
    if (![array isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    NSMutableSet *seenStrings = [NSMutableSet set];
    for (id item in array) {
        if ([item isKindOfClass:NSString.class] && [item length] > 0 && ![seenStrings containsObject:item]) {
            NSString *string = [item copy];
            [seenStrings addObject:string];
            [strings addObject:string];
        }
    }
    return [strings copy];
}

+ (LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [self stringInUserInfo:userInfo forKey:LAIPCKeyEventName];
    if (eventName.length == 0) {
        return nil;
    }

    id handledValue = userInfo[LAIPCKeyEventHandled];
    if (handledValue && ![handledValue isKindOfClass:NSNumber.class]) {
        return nil;
    }
    id modeValue = userInfo[LAIPCKeyEventMode];
    if (modeValue && ![modeValue isKindOfClass:NSString.class]) {
        return nil;
    }
    id eventUserInfo = userInfo[LAIPCKeyEventUserInfo];
    if (eventUserInfo &&
        (![eventUserInfo isKindOfClass:NSDictionary.class] || ![self isPropertyListValue:eventUserInfo])) {
        return nil;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:modeValue];
    event.handled = [handledValue boolValue];
    if (eventUserInfo) {
        event.userInfo = [self propertyListValue:eventUserInfo];
    }
    return event;
}

+ (NSDictionary *)userInfoWithEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAIPCKeyEventMode] = event.mode;
    }
    userInfo[LAIPCKeyEventHandled] = @(event.handled);
    NSDictionary *eventUserInfo = [self propertyListValue:event.userInfo];
    if (eventUserInfo) {
        userInfo[LAIPCKeyEventUserInfo] = eventUserInfo;
    }
    return [userInfo copy];
}

+ (NSDictionary *)userInfoWithEvent:(LAEvent *)event listenerName:(NSString *)listenerName {
    if (event.name.length == 0) {
        return @{};
    }
    NSMutableDictionary *userInfo = [[self userInfoWithEvent:event] mutableCopy];
    userInfo[LAIPCKeyListenerName] = [listenerName copy] ?: @"";
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

+ (BOOL)isPropertyListValue:(id)value {
    NSHashTable *activeContainers = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    return [self isPropertyListValue:value depth:0 activeContainers:activeContainers];
}

+ (BOOL)isPropertyListValue:(id)value depth:(NSUInteger)depth activeContainers:(NSHashTable *)activeContainers {
    if (!value) {
        return NO;
    }

    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] ||
        [value isKindOfClass:NSData.class] || [value isKindOfClass:NSDate.class]) {
        return YES;
    }

    if (depth >= LAIPCCodecMaximumPropertyListDepth) {
        return NO;
    }

    if ([value isKindOfClass:NSDictionary.class]) {
        if ([activeContainers containsObject:value]) {
            return NO;
        }
        [activeContainers addObject:value];

        for (id key in value) {
            if (![key isKindOfClass:NSString.class] || ![self isPropertyListValue:value[key]
                                                                            depth:depth + 1
                                                                 activeContainers:activeContainers]) {
                [activeContainers removeObject:value];
                return NO;
            }
        }

        [activeContainers removeObject:value];
        return YES;
    }

    if ([value isKindOfClass:NSArray.class]) {
        if ([activeContainers containsObject:value]) {
            return NO;
        }
        [activeContainers addObject:value];

        for (id item in value) {
            if (![self isPropertyListValue:item depth:depth + 1 activeContainers:activeContainers]) {
                [activeContainers removeObject:value];
                return NO;
            }
        }

        [activeContainers removeObject:value];
        return YES;
    }

    return NO;
}

+ (id)propertyListValue:(id)value {
    NSHashTable *activeContainers = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    return [self propertyListValue:value depth:0 activeContainers:activeContainers];
}

+ (id)propertyListValue:(id)value depth:(NSUInteger)depth activeContainers:(NSHashTable *)activeContainers {
    if (!value) {
        return nil;
    }

    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] ||
        [value isKindOfClass:NSData.class] || [value isKindOfClass:NSDate.class]) {
        return [value copy];
    }

    if (depth >= LAIPCCodecMaximumPropertyListDepth) {
        return nil;
    }

    if ([value isKindOfClass:NSDictionary.class]) {
        if ([activeContainers containsObject:value]) {
            return nil;
        }
        [activeContainers addObject:value];

        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) {
            if (![key isKindOfClass:NSString.class]) {
                continue;
            }
            id sanitizedValue = [self propertyListValue:value[key] depth:depth + 1 activeContainers:activeContainers];
            if (sanitizedValue) {
                dictionary[key] = sanitizedValue;
            }
        }
        [activeContainers removeObject:value];
        return [dictionary copy];
    }

    if ([value isKindOfClass:NSArray.class]) {
        if ([activeContainers containsObject:value]) {
            return nil;
        }
        [activeContainers addObject:value];

        NSMutableArray *array = [NSMutableArray arrayWithCapacity:[value count]];
        for (id item in value) {
            id sanitizedItem = [self propertyListValue:item depth:depth + 1 activeContainers:activeContainers];
            if (sanitizedItem) {
                [array addObject:sanitizedItem];
            }
        }
        [activeContainers removeObject:value];
        return [array copy];
    }

    return nil;
}

+ (NSDictionary *)smallIconDataReplyWithData:(NSData *)data scale:(CGFloat)scale {
    if (data.length == 0 || !isfinite((double)scale) || scale <= 0.0) {
        return [self replyWithOK:NO value:nil];
    }
    return @{LAIPCKeyOK : @YES, LAIPCKeyValue : data, LAIPCKeyScale : @(scale)};
}

@end
