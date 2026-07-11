//
//  LATNetworkEventDataSource.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATNetworkEventDataSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"
#import "LATEventSourceRegistry.h"
#import "LATNetworkEventSource.h"

#import <HBLog.h>

static NSString *const LATNetworkStatusEventsPreferenceKey = @"LANetworkStatusEvents";

@interface LATNetworkEventDataSource ()

@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, weak) LATNetworkEventSource *eventSource;
@property(nonatomic, weak) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, copy, readwrite) NSSet<NSString *> *configuredEventNames;

@end

@implementation LATNetworkEventDataSource

- (instancetype)initWithActivator:(LAActivator *)activator eventSource:(LATNetworkEventSource *)eventSource {
    LAAssertMainQueue();
    NSParameterAssert(activator);
    NSParameterAssert(eventSource);

    self = [super init];
    if (self) {
        _activator = activator;
        _eventSource = eventSource;
        _configuredEventNames = [self
            normalizedConfiguredEventNames:[activator _getObjectForPreference:LATNetworkStatusEventsPreferenceKey]];
        [eventSource updateConfiguredEventNames:_configuredEventNames];
    }
    return self;
}

- (void)attachEventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry {
    LAAssertMainQueue();
    NSParameterAssert(eventSourceRegistry);
    NSAssert(!self.eventSourceRegistry || self.eventSourceRegistry == eventSourceRegistry,
             @"Network event data source cannot change registries");
    self.eventSourceRegistry = eventSourceRegistry;
}

- (NSString *)addEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName {
    LAAssertMainQueue();
    if (![self isSupportedBaseEventName:baseEventName] || networkName.length == 0) {
        return nil;
    }

    NSString *eventName = [baseEventName stringByAppendingFormat:@".%@", networkName];
    if ([self.configuredEventNames containsObject:eventName]) {
        return eventName;
    }

    NSMutableSet<NSString *> *configuredEventNames = [self.configuredEventNames mutableCopy];
    [configuredEventNames addObject:eventName];
    return [self applyConfiguredEventNames:configuredEventNames] ? eventName : nil;
}

#pragma mark - LAEventDataSource

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    NSString *baseEventName = [self baseEventNameForConfiguredEventName:eventName];
    NSString *networkName = [self networkNameForConfiguredEventName:eventName baseEventName:baseEventName];
    NSString *formatKey = [NSString stringWithFormat:@"NEW_EVENT_TITLE_%@_FORMAT", baseEventName ?: @""];
    NSString *format = [self.activator localizedStringForKey:formatKey value:@"%@"];
    return networkName.length > 0 ? [NSString stringWithFormat:format, networkName] : eventName;
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    NSString *baseEventName = [self baseEventNameForConfiguredEventName:eventName];
    return baseEventName.length > 0 ? [self.activator localizedGroupForEventName:baseEventName] : @"";
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    NSString *baseEventName = [self baseEventNameForConfiguredEventName:eventName];
    NSString *networkName = [self networkNameForConfiguredEventName:eventName baseEventName:baseEventName];
    NSString *formatKey = [NSString stringWithFormat:@"NEW_EVENT_DESCRIPTION_%@_FORMAT", baseEventName ?: @""];
    NSString *format = [self.activator localizedStringForKey:formatKey value:@"%@"];
    return networkName.length > 0 ? [NSString stringWithFormat:format, networkName] : eventName;
}

- (BOOL)eventWithNameRequiresAssignment:(__unused NSString *)eventName {
    return YES;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    NSString *baseEventName = [self baseEventNameForConfiguredEventName:eventName];
    return baseEventName.length > 0 && [self.activator eventWithName:baseEventName isCompatibleWithMode:eventMode];
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    return [self.configuredEventNames containsObject:eventName];
}

- (void)removeEventWithName:(NSString *)eventName {
    LAAssertMainQueue();
    if (![self.configuredEventNames containsObject:eventName]) {
        return;
    }

    NSMutableSet<NSString *> *configuredEventNames = [self.configuredEventNames mutableCopy];
    [configuredEventNames removeObject:eventName];
    [self applyConfiguredEventNames:configuredEventNames];
}

#pragma mark - Configuration Snapshot

- (BOOL)applyConfiguredEventNames:(NSSet<NSString *> *)configuredEventNames {
    LAAssertMainQueue();
    NSSet<NSString *> *normalizedEventNames = [self normalizedConfiguredEventNames:configuredEventNames];
    if ([normalizedEventNames isEqualToSet:self.configuredEventNames]) {
        return YES;
    }

    NSSet<NSString *> *previousEventNames = self.configuredEventNames;
    self.configuredEventNames = normalizedEventNames;
    [self.eventSource updateConfiguredEventNames:normalizedEventNames];
    if (![self.eventSourceRegistry reloadEventNamesForEventSource:self.eventSource]) {
        self.configuredEventNames = previousEventNames;
        [self.eventSource updateConfiguredEventNames:previousEventNames];
        [self.eventSourceRegistry reloadEventNamesForEventSource:self.eventSource];
        HBLogError(@"Unable to apply configured network event definitions");
        return NO;
    }

    NSArray<NSString *> *orderedEventNames =
        [normalizedEventNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [self.activator _setObject:orderedEventNames forPreference:LATNetworkStatusEventsPreferenceKey];
    return YES;
}

- (NSSet<NSString *> *)normalizedConfiguredEventNames:(id)value {
    NSArray *eventNames = nil;
    if ([value isKindOfClass:NSArray.class]) {
        eventNames = value;
    } else if ([value isKindOfClass:NSSet.class]) {
        eventNames = [value allObjects];
    } else {
        eventNames = @[];
    }

    NSMutableSet<NSString *> *normalizedEventNames = [[NSMutableSet alloc] init];
    for (id eventName in eventNames) {
        if ([eventName isKindOfClass:NSString.class] && [self baseEventNameForConfiguredEventName:eventName]) {
            [normalizedEventNames addObject:eventName];
        }
    }
    return [normalizedEventNames copy];
}

- (BOOL)isSupportedBaseEventName:(NSString *)eventName {
    return [eventName isEqualToString:LAEventNameNetworkJoinedWiFi] ||
           [eventName isEqualToString:LAEventNameNetworkLeftWiFi];
}

- (nullable NSString *)baseEventNameForConfiguredEventName:(NSString *)eventName {
    for (NSString *baseEventName in @[ LAEventNameNetworkJoinedWiFi, LAEventNameNetworkLeftWiFi ]) {
        NSString *prefix = [baseEventName stringByAppendingString:@"."];
        if ([eventName hasPrefix:prefix] && eventName.length > prefix.length) {
            return baseEventName;
        }
    }
    return nil;
}

- (nullable NSString *)networkNameForConfiguredEventName:(NSString *)eventName baseEventName:(NSString *)baseEventName {
    if (baseEventName.length == 0) {
        return nil;
    }
    return [eventName substringFromIndex:baseEventName.length + 1];
}

@end
