#import "LAActivatorIPC.h"
#import "LAActivatorPrivate.h"
#import "LAActivatorResourceManager.h"

#import <AppSupport/CPDistributedMessagingCenter.h>
#import <dispatch/dispatch.h>

@interface LAActivatorIPCServer ()
- (NSDictionary *)replyWithOK:(BOOL)ok value:(id)value;
- (NSDictionary *)eventReplyWithEvent:(LAEvent *)event;
- (NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
- (NSArray *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
- (NSArray *)orderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
- (LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)userInfoWithEvent:(LAEvent *)event;
- (NSArray *)eventDictionariesWithEvents:(NSArray *)events;
- (id)propertyListValue:(id)value;
- (NSDictionary *)iconDataReplyForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat)scale;
- (void)sendEvent:(LAEvent *)event directlyToListenerName:(NSString *)listenerName abort:(BOOL)abort;
@end

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
        LAActivatorIPCMessageHasSeenListener,
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
        LAActivatorIPCMessageDispatchAssignedEvent,
        LAActivatorIPCMessageDispatchEventToListeners,
        LAActivatorIPCMessageDispatchAssignedAbortEvent,
        LAActivatorIPCMessageDispatchAbortEventToListeners,
        LAActivatorIPCMessageDispatchPreviewEvent,
        LAActivatorIPCMessageDispatchDeactivateEvent,
        LAActivatorIPCMessageRemoteListenerReceiveEvent,
        LAActivatorIPCMessageRemoteListenerAbortEvent,
        LAActivatorIPCMessageListenerIconData,
        LAActivatorIPCMessageListenerSmallIconData,
        LAActivatorIPCMessageRequestListenerRemoval,
        LAActivatorIPCMessageRemoveEvent,
    ];
    for (NSString *messageName in messageNames) {
        [_center registerForMessageName:messageName target:self selector:@selector(handleMessageNamed:withUserInfo:)];
    }
    [_center runServerOnCurrentThread];
    _started = YES;
}

- (NSDictionary *)handleMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if (![messageName isKindOfClass:NSString.class] || ![userInfo isKindOfClass:NSDictionary.class]) {
        return [self replyWithOK:NO value:nil];
    }

    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableEventNames]) {
        return [self replyWithOK:YES value:_activator.availableEventNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasEvent]) {
        return [self replyWithOK:YES
                           value:@([_activator hasEventWithName:[self stringInUserInfo:userInfo
                                                                                forKey:LAActivatorIPCKeyEventName]])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableListenerNames]) {
        return [self replyWithOK:YES value:_activator.availableListenerNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasListener]) {
        return [self
            replyWithOK:YES
                  value:@([_activator hasListenerWithName:[self stringInUserInfo:userInfo
                                                                          forKey:LAActivatorIPCKeyListenerName]])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasSeenListener]) {
        return [self
            replyWithOK:YES
                  value:@([_activator hasSeenListenerWithName:[self stringInUserInfo:userInfo
                                                                               forKey:LAActivatorIPCKeyListenerName]])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignedListenerNames]) {
        return [self replyWithOK:YES
                           value:[_activator assignedListenerNamesForEvent:[self eventWithUserInfo:userInfo]]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventsAssignedToListener]) {
        NSArray *events = [_activator
            eventsAssignedToListenerWithName:[self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName]];
        return [self replyWithOK:YES value:[self eventDictionariesWithEvents:events]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        BOOL changed = [_activator la_assignEvent:event
                             toListenersWithNames:[self stringArrayInUserInfo:userInfo
                                                                       forKey:LAActivatorIPCKeyListenerNames]];
        if (changed) {
            [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification
                                                              object:_activator];
        }
        return [self replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageUnassignEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        BOOL changed = [_activator la_unassignEvent:event];
        if (changed) {
            [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification
                                                              object:_activator];
        }
        return [self replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageApplicationIsBlacklisted]) {
        NSString *displayIdentifier = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyDisplayIdentifier];
        return [self replyWithOK:YES
                           value:@([_activator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetApplicationBlacklisted]) {
        BOOL changed = [_activator
            la_setApplicationWithDisplayIdentifier:[self stringInUserInfo:userInfo
                                                                   forKey:LAActivatorIPCKeyDisplayIdentifier]
                                     isBlacklisted:[userInfo[LAActivatorIPCKeyBlacklisted] boolValue]];
        return [self replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableProfileNames]) {
        return [self replyWithOK:YES value:_activator.availableProfileNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentProfileName]) {
        return [self replyWithOK:YES value:_activator.currentProfileName ?: @""];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetCurrentProfileName]) {
        BOOL changed = [_activator la_setCurrentProfileName:[self stringInUserInfo:userInfo
                                                                            forKey:LAActivatorIPCKeyProfileName]];
        return [self replyWithOK:YES value:@(changed)];
    }

    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAssignedEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        [_activator sendEventToListener:event];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchEventToListeners]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        [_activator sendEvent:event
            toListenersWithNames:[self orderedStringArrayInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerNames]];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAssignedAbortEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        [_activator sendAbortToListener:event];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAbortEventToListeners]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        [_activator sendAbortEvent:event
              toListenersWithNames:[self orderedStringArrayInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerNames]];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchPreviewEvent]) {
        [_activator sendPreviewEventToListenerWithName:[self stringInUserInfo:userInfo
                                                                       forKey:LAActivatorIPCKeyListenerName]];
        return [self replyWithOK:YES value:nil];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchDeactivateEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        if (!event) {
            return [self replyWithOK:NO value:nil];
        }
        [_activator sendDeactivateEventToListeners:event];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoteListenerReceiveEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        NSString *targetListenerName = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [self replyWithOK:NO value:nil];
        }
        [self sendEvent:event directlyToListenerName:targetListenerName abort:NO];
        return [self eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoteListenerAbortEvent]) {
        LAEvent *event = [self eventWithUserInfo:userInfo];
        NSString *targetListenerName = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [self replyWithOK:NO value:nil];
        }
        [self sendEvent:event directlyToListenerName:targetListenerName abort:YES];
        return [self eventReplyWithEvent:event];
    }

    NSString *eventName = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    NSString *listenerName = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
    NSString *eventMode = [self stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventMode];
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsHidden]) {
        return [self replyWithOK:YES value:@([_activator eventWithNameIsHidden:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventRequiresAssignment]) {
        return [self replyWithOK:YES value:@([_activator eventWithNameRequiresAssignment:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForEvent]) {
        return [self replyWithOK:YES value:[_activator compatibleModesForEventWithName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsCompatibleWithMode]) {
        return [self replyWithOK:YES value:@([_activator eventWithName:eventName isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend]) {
        return [self replyWithOK:YES value:@([_activator eventWithNameSupportsUnlockingDeviceToSend:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsRemoval]) {
        return [self replyWithOK:YES value:@([_activator eventWithNameSupportsRemoval:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsConfiguration]) {
        return [self replyWithOK:YES value:@([_activator eventWithNameSupportsConfiguration:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoveEvent]) {
        [_activator removeEventWithName:eventName];
        return [self replyWithOK:YES value:nil];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerInfoDictionaryValue]) {
        id value = [_activator infoDictionaryValueOfKey:[self stringInUserInfo:userInfo
                                                                        forKey:LAActivatorIPCKeyInfoDictionaryKey]
                                    forListenerWithName:listenerName];
        id propertyListValue = [self propertyListValue:value];
        return [self replyWithOK:propertyListValue != nil value:propertyListValue];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerRequiresAssignment]) {
        return [self replyWithOK:YES value:@([_activator listenerWithNameRequiresAssignment:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForListener]) {
        return [self replyWithOK:YES value:[_activator compatibleEventModesForListenerWithName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithMode]) {
        return [self replyWithOK:YES
                           value:@([_activator listenerWithName:listenerName isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithEvent]) {
        return [self replyWithOK:YES
                           value:@([_activator listenerWithName:listenerName isCompatibleWithEventName:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNeedsPoweredDisplay]) {
        return [self replyWithOK:YES value:@([_activator listenerWithNameNeedsPoweredDisplay:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageExclusiveAssignmentGroupsForListener]) {
        return [self replyWithOK:YES value:[_activator exclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNamesAreMutuallyCompatible]) {
        NSArray *listenerNames = [self stringArrayInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerNames];
        return [self replyWithOK:YES value:@([_activator listenerNamesAreMutuallyCompatible:listenerNames])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsRemoval]) {
        return [self replyWithOK:YES value:@([_activator listenerWithNameSupportsRemoval:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsConfiguration]) {
        return [self replyWithOK:YES value:@([_activator listenerWithNameSupportsConfiguration:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIconData]) {
        return [self iconDataReplyForListenerName:listenerName
                                            small:NO
                                            scale:[userInfo[LAActivatorIPCKeyScale] doubleValue]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSmallIconData]) {
        return [self iconDataReplyForListenerName:listenerName
                                            small:YES
                                            scale:[userInfo[LAActivatorIPCKeyScale] doubleValue]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRequestListenerRemoval]) {
        [_activator requestRemovalForListenerWithName:listenerName];
        return [self replyWithOK:YES value:nil];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForEventName]) {
        return [self replyWithOK:YES value:[_activator localizedTitleForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerName]) {
        return [self replyWithOK:YES value:[_activator localizedTitleForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerNames]) {
        NSArray *listenerNames = [self orderedStringArrayInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerNames];
        return [self replyWithOK:YES value:[_activator localizedTitleForListenerNames:listenerNames]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForEventName]) {
        return [self replyWithOK:YES value:[_activator localizedGroupForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForListenerName]) {
        return [self replyWithOK:YES value:[_activator localizedGroupForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForEventName]) {
        return [self replyWithOK:YES value:[_activator localizedDescriptionForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForListenerName]) {
        return [self replyWithOK:YES value:[_activator localizedDescriptionForListenerName:listenerName]];
    }

    return [self replyWithOK:NO value:nil];
}

#pragma mark - Serialization

- (NSDictionary *)replyWithOK:(BOOL)ok value:(id)value {
    if (value) {
        return @{LAActivatorIPCKeyOK : @(ok), LAActivatorIPCKeyValue : value};
    }
    return @{LAActivatorIPCKeyOK : @(ok)};
}

- (NSDictionary *)eventReplyWithEvent:(LAEvent *)event {
    return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyEventHandled : @([event isHandled])};
}

- (NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
    id value = userInfo[key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

- (NSArray *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
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

- (NSArray *)orderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key {
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

- (LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo {
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

- (NSDictionary *)userInfoWithEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAActivatorIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAActivatorIPCKeyEventMode] = event.mode;
    }
    return [userInfo copy];
}

- (NSArray *)eventDictionariesWithEvents:(NSArray *)events {
    NSMutableArray *dictionaries = [NSMutableArray arrayWithCapacity:events.count];
    for (LAEvent *event in events) {
        if ([event isKindOfClass:LAEvent.class] && event.name.length > 0) {
            [dictionaries addObject:[self userInfoWithEvent:event]];
        }
    }
    return [dictionaries copy];
}

- (id)propertyListValue:(id)value {
    if (!value) {
        return nil;
    }
    return [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0] ? value
                                                                                                             : nil;
}

- (NSDictionary *)iconDataReplyForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat)scale {
    if (listenerName.length == 0) {
        return [self replyWithOK:NO value:nil];
    }

    CGFloat actualScale = scale > 0.0f ? scale : UIScreen.mainScreen.scale;
    NSData *data = nil;
    id<LAListener> listener = [_activator listenerForName:listenerName];
    if (small) {
        if ([listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:scale:)]) {
            data = [listener activator:_activator requiresSmallIconDataForListenerName:listenerName scale:&actualScale];
        }
        if (data.length == 0 && [listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:)]) {
            data = [listener activator:_activator requiresSmallIconDataForListenerName:listenerName];
            actualScale = 1.0f;
        }
    } else {
        if ([listener respondsToSelector:@selector(activator:requiresIconDataForListenerName:scale:)]) {
            data = [listener activator:_activator requiresIconDataForListenerName:listenerName scale:&actualScale];
        }
        if (data.length == 0 && [listener respondsToSelector:@selector(activator:requiresIconDataForListenerName:)]) {
            data = [listener activator:_activator requiresIconDataForListenerName:listenerName];
            actualScale = 1.0f;
        }
    }
    if (data.length == 0) {
        data = [LAActivatorResourceManager.sharedManager iconDataForListenerName:listenerName small:small scale:&actualScale];
    }
    if (data.length == 0) {
        return [self replyWithOK:NO value:nil];
    }
    return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyValue : data, LAActivatorIPCKeyScale : @(actualScale)};
}

- (void)sendEvent:(LAEvent *)event directlyToListenerName:(NSString *)listenerName abort:(BOOL)abort {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendEvent:event directlyToListenerName:listenerName abort:abort];
        });
        return;
    }

    id<LAListener> listener = [_activator listenerForName:listenerName];
    if (!listener) {
        return;
    }
    if (abort) {
        if ([listener respondsToSelector:@selector(activator:abortEvent:forListenerName:)]) {
            [listener activator:_activator abortEvent:event forListenerName:listenerName];
        } else if ([listener respondsToSelector:@selector(activator:abortEvent:)]) {
            [listener activator:_activator abortEvent:event];
        }
        return;
    }
    if ([listener respondsToSelector:@selector(activator:receiveEvent:forListenerName:)]) {
        [listener activator:_activator receiveEvent:event forListenerName:listenerName];
    } else if ([listener respondsToSelector:@selector(activator:receiveEvent:)]) {
        [listener activator:_activator receiveEvent:event];
    }
}

@end
