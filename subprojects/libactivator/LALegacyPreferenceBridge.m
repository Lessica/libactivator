//
//  LALegacyPreferenceBridge.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LALegacyPreferenceBridge.h"

#import "LAActivatorBackend.h"

static NSString *const LALegacyAssignmentPrefix = @"LAEventListener(";
static NSString *const LALegacyBlacklistPrefix = @"LABlacklisted-";
static NSString *const LALegacyHasSeenPrefix = @"LAHasSeenListener-";

@interface LALegacyPreferenceBridge ()
@property(nonatomic, strong) LAActivatorBackend *backend;
@end

@implementation LALegacyPreferenceBridge

- (instancetype)initWithBackend:(LAActivatorBackend *)backend {
    self = [super init];
    if (self) {
        _backend = backend;
    }
    return self;
}

- (id)objectForPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return nil;
    }

    NSDictionary *assignment = [self assignmentComponentsForKey:key];
    if (assignment) {
        NSArray *listenerNames = [self.backend assignedListenerNamesForEventName:assignment[@"EventName"]
                                                                            mode:assignment[@"EventMode"]];
        return listenerNames.count > 0 ? listenerNames[0] : nil;
    }

    if ([key hasPrefix:LALegacyBlacklistPrefix]) {
        NSString *displayIdentifier = [key substringFromIndex:LALegacyBlacklistPrefix.length];
        return [self.backend applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier] ? @YES : nil;
    }

    if ([key hasPrefix:LALegacyHasSeenPrefix]) {
        NSString *listenerName = [key substringFromIndex:LALegacyHasSeenPrefix.length];
        return [self.backend hasSeenListenerWithName:listenerName] ? @YES : nil;
    }

    return [self.backend objectForLegacyPreferenceKey:key];
}

- (BOOL)setObject:(id)object forPreferenceKey:(NSString *)key {
    if (key.length == 0) {
        return NO;
    }

    NSDictionary *assignment = [self assignmentComponentsForKey:key];
    if (assignment) {
        NSString *listenerName = [object isKindOfClass:NSString.class] && [object length] > 0 ? object : nil;
        return [self.backend assignEventName:assignment[@"EventName"]
                                        mode:assignment[@"EventMode"]
                             toListenerNames:listenerName ? @[ listenerName ] : @[]];
    }

    if ([key hasPrefix:LALegacyBlacklistPrefix]) {
        NSString *displayIdentifier = [key substringFromIndex:LALegacyBlacklistPrefix.length];
        return [self.backend setApplicationWithDisplayIdentifier:displayIdentifier
                                                   isBlacklisted:[self isTruthyObject:object]];
    }

    if ([key hasPrefix:LALegacyHasSeenPrefix]) {
        NSString *listenerName = [key substringFromIndex:LALegacyHasSeenPrefix.length];
        return [self.backend setListenerName:listenerName seen:[self isTruthyObject:object]];
    }

    if (object && ![NSPropertyListSerialization propertyList:object isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        return NO;
    }
    return [self.backend setObject:object forLegacyPreferenceKey:key];
}

- (NSDictionary *)assignmentComponentsForKey:(NSString *)key {
    if (![key hasPrefix:LALegacyAssignmentPrefix]) {
        return nil;
    }

    NSRange separatorRange =
        [key rangeOfString:@")-"
                   options:0
                     range:NSMakeRange(LALegacyAssignmentPrefix.length, key.length - LALegacyAssignmentPrefix.length)];
    if (separatorRange.location == NSNotFound) {
        return nil;
    }

    NSUInteger modeStart = LALegacyAssignmentPrefix.length;
    NSString *mode = [key substringWithRange:NSMakeRange(modeStart, separatorRange.location - modeStart)];
    NSString *eventName = [key substringFromIndex:NSMaxRange(separatorRange)];
    if (eventName.length == 0) {
        return nil;
    }
    return @{
        @"EventMode" : mode ?: @"",
        @"EventName" : eventName,
    };
}

- (BOOL)isTruthyObject:(id)object {
    return object && [object respondsToSelector:@selector(boolValue)] && [object boolValue];
}

@end
