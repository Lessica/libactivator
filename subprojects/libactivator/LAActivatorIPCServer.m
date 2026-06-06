#import "LAActivatorIPC.h"

#import <Activator/Activator.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAActivator (IPCServer)
- (BOOL)la_assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)la_unassignEvent:(LAEvent *)event;
- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(NSString *)currentProfileName;
@end

static NSDictionary *LAIPCReply(BOOL ok, id value) {
    if (value) {
        return @{LAActivatorIPCKeyOK : @(ok), LAActivatorIPCKeyValue : value};
    }
    return @{LAActivatorIPCKeyOK : @(ok)};
}

static NSString *LAIPCString(NSDictionary *userInfo, NSString *key) {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSArray *LAIPCStringArray(NSDictionary *userInfo, NSString *key) {
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

static NSArray *LAIPCOrderedStringArray(NSDictionary *userInfo, NSString *key) {
    id value = userInfo[key];
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:[value count]];
    for (id item in value) {
        if ([item isKindOfClass:NSString.class] && [item length] > 0) {
            [strings addObject:item];
        }
    }
    return [strings copy];
}

static LAEvent *LAIPCEvent(NSDictionary *userInfo) {
    NSString *eventName = LAIPCString(userInfo, LAActivatorIPCKeyEventName);
    if (eventName.length == 0) {
        return nil;
    }
    return [LAEvent eventWithName:eventName mode:LAIPCString(userInfo, LAActivatorIPCKeyEventMode)];
}

static NSDictionary *LAIPCUserInfoForEvent(LAEvent *event) {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAActivatorIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAActivatorIPCKeyEventMode] = event.mode;
    }
    return [userInfo copy];
}

static NSArray *LAIPCEventDictionaries(NSArray *events) {
    NSMutableArray *dictionaries = [NSMutableArray arrayWithCapacity:events.count];
    for (LAEvent *event in events) {
        if ([event isKindOfClass:LAEvent.class] && event.name.length > 0) {
            [dictionaries addObject:LAIPCUserInfoForEvent(event)];
        }
    }
    return [dictionaries copy];
}

static id LAIPCPropertyListValue(id value) {
    if (!value) {
        return nil;
    }
    return [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0] ? value : nil;
}

@implementation LAActivatorIPCServer {
    LAActivator *_activator;
    CPDistributedMessagingCenter *_center;
    BOOL _started;
}

#pragma mark - Lifecycle

- (instancetype)initWithActivator:(LAActivator *)activator {
    self = [super init];
    if (self) {
        _activator = activator;
        _center = [CPDistributedMessagingCenter centerNamed:LAActivatorIPCServerName];
    }
    return self;
}

#pragma mark - Server

- (void)start {
    if (_started) {
        return;
    }

    NSArray *messageNames = @[
        LAActivatorIPCMessageAvailableEventNames,
        LAActivatorIPCMessageHasEvent,
        LAActivatorIPCMessageAvailableListenerNames,
        LAActivatorIPCMessageHasListener,
        LAActivatorIPCMessageAssignedListenerNames,
        LAActivatorIPCMessageEventsAssignedToListener,
        LAActivatorIPCMessageAssignEvent,
        LAActivatorIPCMessageUnassignEvent,
        LAActivatorIPCMessageApplicationIsBlacklisted,
        LAActivatorIPCMessageSetApplicationBlacklisted,
        LAActivatorIPCMessageAvailableProfileNames,
        LAActivatorIPCMessageCurrentProfileName,
        LAActivatorIPCMessageSetCurrentProfileName,
        LAActivatorIPCMessageEventIsHidden,
        LAActivatorIPCMessageEventRequiresAssignment,
        LAActivatorIPCMessageCompatibleModesForEvent,
        LAActivatorIPCMessageEventIsCompatibleWithMode,
        LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend,
        LAActivatorIPCMessageEventSupportsRemoval,
        LAActivatorIPCMessageEventSupportsConfiguration,
        LAActivatorIPCMessageListenerInfoDictionaryValue,
        LAActivatorIPCMessageListenerRequiresAssignment,
        LAActivatorIPCMessageCompatibleModesForListener,
        LAActivatorIPCMessageListenerIsCompatibleWithMode,
        LAActivatorIPCMessageListenerIsCompatibleWithEvent,
        LAActivatorIPCMessageListenerNeedsPoweredDisplay,
        LAActivatorIPCMessageExclusiveAssignmentGroupsForListener,
        LAActivatorIPCMessageListenerNamesAreMutuallyCompatible,
        LAActivatorIPCMessageListenerSupportsRemoval,
        LAActivatorIPCMessageListenerSupportsConfiguration,
        LAActivatorIPCMessageLocalizedTitleForEventName,
        LAActivatorIPCMessageLocalizedTitleForListenerName,
        LAActivatorIPCMessageLocalizedTitleForListenerNames,
        LAActivatorIPCMessageLocalizedGroupForEventName,
        LAActivatorIPCMessageLocalizedGroupForListenerName,
        LAActivatorIPCMessageLocalizedDescriptionForEventName,
        LAActivatorIPCMessageLocalizedDescriptionForListenerName,
    ];
    for (NSString *messageName in messageNames) {
        [_center registerForMessageName:messageName target:self selector:@selector(handleMessageNamed:withUserInfo:)];
    }
    [_center runServer];
    _started = YES;
}

- (NSDictionary *)handleMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if (![messageName isKindOfClass:NSString.class] || ![userInfo isKindOfClass:NSDictionary.class]) {
        return LAIPCReply(NO, nil);
    }

    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableEventNames]) {
        return LAIPCReply(YES, _activator.availableEventNames);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasEvent]) {
        return LAIPCReply(YES, @([_activator hasEventWithName:LAIPCString(userInfo, LAActivatorIPCKeyEventName)]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableListenerNames]) {
        return LAIPCReply(YES, _activator.availableListenerNames);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasListener]) {
        return LAIPCReply(YES, @([_activator hasListenerWithName:LAIPCString(userInfo, LAActivatorIPCKeyListenerName)]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignedListenerNames]) {
        return LAIPCReply(YES, [_activator assignedListenerNamesForEvent:LAIPCEvent(userInfo)]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventsAssignedToListener]) {
        NSArray *events = [_activator eventsAssignedToListenerWithName:LAIPCString(userInfo, LAActivatorIPCKeyListenerName)];
        return LAIPCReply(YES, LAIPCEventDictionaries(events));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignEvent]) {
        LAEvent *event = LAIPCEvent(userInfo);
        if (!event) {
            return LAIPCReply(NO, nil);
        }
        BOOL changed = [_activator la_assignEvent:event
                             toListenersWithNames:LAIPCStringArray(userInfo, LAActivatorIPCKeyListenerNames)];
        if (changed) {
            [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification
                                                              object:_activator];
        }
        return LAIPCReply(YES, @(changed));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageUnassignEvent]) {
        LAEvent *event = LAIPCEvent(userInfo);
        if (!event) {
            return LAIPCReply(NO, nil);
        }
        BOOL changed = [_activator la_unassignEvent:event];
        if (changed) {
            [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification
                                                              object:_activator];
        }
        return LAIPCReply(YES, @(changed));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageApplicationIsBlacklisted]) {
        return LAIPCReply(YES, @([_activator applicationWithDisplayIdentifierIsBlacklisted:
                                      LAIPCString(userInfo, LAActivatorIPCKeyDisplayIdentifier)]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetApplicationBlacklisted]) {
        BOOL changed =
            [_activator la_setApplicationWithDisplayIdentifier:LAIPCString(userInfo, LAActivatorIPCKeyDisplayIdentifier)
                                                 isBlacklisted:[userInfo[LAActivatorIPCKeyBlacklisted] boolValue]];
        return LAIPCReply(YES, @(changed));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableProfileNames]) {
        return LAIPCReply(YES, _activator.availableProfileNames);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentProfileName]) {
        return LAIPCReply(YES, _activator.currentProfileName ?: @"");
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetCurrentProfileName]) {
        BOOL changed = [_activator la_setCurrentProfileName:LAIPCString(userInfo, LAActivatorIPCKeyProfileName)];
        return LAIPCReply(YES, @(changed));
    }

    NSString *eventName = LAIPCString(userInfo, LAActivatorIPCKeyEventName);
    NSString *listenerName = LAIPCString(userInfo, LAActivatorIPCKeyListenerName);
    NSString *eventMode = LAIPCString(userInfo, LAActivatorIPCKeyEventMode);
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsHidden]) {
        return LAIPCReply(YES, @([_activator eventWithNameIsHidden:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventRequiresAssignment]) {
        return LAIPCReply(YES, @([_activator eventWithNameRequiresAssignment:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForEvent]) {
        return LAIPCReply(YES, [_activator compatibleModesForEventWithName:eventName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsCompatibleWithMode]) {
        return LAIPCReply(YES, @([_activator eventWithName:eventName isCompatibleWithMode:eventMode]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend]) {
        return LAIPCReply(YES, @([_activator eventWithNameSupportsUnlockingDeviceToSend:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsRemoval]) {
        return LAIPCReply(YES, @([_activator eventWithNameSupportsRemoval:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsConfiguration]) {
        return LAIPCReply(YES, @([_activator eventWithNameSupportsConfiguration:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerInfoDictionaryValue]) {
        id value = [_activator infoDictionaryValueOfKey:LAIPCString(userInfo, LAActivatorIPCKeyInfoDictionaryKey)
                                    forListenerWithName:listenerName];
        id propertyListValue = LAIPCPropertyListValue(value);
        return LAIPCReply(propertyListValue != nil, propertyListValue);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerRequiresAssignment]) {
        return LAIPCReply(YES, @([_activator listenerWithNameRequiresAssignment:listenerName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForListener]) {
        return LAIPCReply(YES, [_activator compatibleEventModesForListenerWithName:listenerName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithMode]) {
        return LAIPCReply(YES, @([_activator listenerWithName:listenerName isCompatibleWithMode:eventMode]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithEvent]) {
        return LAIPCReply(YES, @([_activator listenerWithName:listenerName isCompatibleWithEventName:eventName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNeedsPoweredDisplay]) {
        return LAIPCReply(YES, @([_activator listenerWithNameNeedsPoweredDisplay:listenerName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageExclusiveAssignmentGroupsForListener]) {
        return LAIPCReply(YES, [_activator exclusiveAssignmentGroupsForListenerName:listenerName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNamesAreMutuallyCompatible]) {
        return LAIPCReply(YES, @([_activator listenerNamesAreMutuallyCompatible:
                                      LAIPCStringArray(userInfo, LAActivatorIPCKeyListenerNames)]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsRemoval]) {
        return LAIPCReply(YES, @([_activator listenerWithNameSupportsRemoval:listenerName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsConfiguration]) {
        return LAIPCReply(YES, @([_activator listenerWithNameSupportsConfiguration:listenerName]));
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForEventName]) {
        return LAIPCReply(YES, [_activator localizedTitleForEventName:eventName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerName]) {
        return LAIPCReply(YES, [_activator localizedTitleForListenerName:listenerName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerNames]) {
        return LAIPCReply(YES, [_activator localizedTitleForListenerNames:
                                    LAIPCOrderedStringArray(userInfo, LAActivatorIPCKeyListenerNames)]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForEventName]) {
        return LAIPCReply(YES, [_activator localizedGroupForEventName:eventName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForListenerName]) {
        return LAIPCReply(YES, [_activator localizedGroupForListenerName:listenerName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForEventName]) {
        return LAIPCReply(YES, [_activator localizedDescriptionForEventName:eventName]);
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForListenerName]) {
        return LAIPCReply(YES, [_activator localizedDescriptionForListenerName:listenerName]);
    }

    return LAIPCReply(NO, nil);
}

@end
