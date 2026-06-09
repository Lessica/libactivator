//
//  LAActivatorIPCServer.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivator+Private.h"
#import "LAActivatorIPC.h"
#import "LAActivatorIPCCodec.h"
#if LA_TESTING
#import "LAActivatorTestSupport.h"
#endif

#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAActivatorIPCServer ()
- (NSArray *)registeredMessageNames;
- (nullable NSDictionary *)handleTestingMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleRegistryMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleAssignmentMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleRuntimeMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleDispatchMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleEventMetadataMessageNamed:(NSString *)messageName
                                              withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleListenerMetadataMessageNamed:(NSString *)messageName
                                                 withUserInfo:(NSDictionary *)userInfo;
- (nullable NSDictionary *)handleLocalizationMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
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

    for (NSString *messageName in [self registeredMessageNames]) {
        [_center registerForMessageName:messageName target:self selector:@selector(handleMessageNamed:withUserInfo:)];
    }
    [_center runServerOnCurrentThread];
    _started = YES;
}

- (NSArray *)registeredMessageNames {
    return @[
        LAActivatorIPCMessageAvailableEventNames,
        LAActivatorIPCMessageHasEvent,
        LAActivatorIPCMessageAvailableListenerNames,
        LAActivatorIPCMessageHasListener,
        LAActivatorIPCMessageHasSeenListener,
        LAActivatorIPCMessageAssignedListenerNames,
        LAActivatorIPCMessageEventsAssignedToListener,
        LAActivatorIPCMessageAssignEvent,
        LAActivatorIPCMessageAddListenerAssignment,
        LAActivatorIPCMessageRemoveListenerAssignment,
        LAActivatorIPCMessageUnassignEvent,
        LAActivatorIPCMessageApplicationIsBlacklisted,
        LAActivatorIPCMessageSetApplicationBlacklisted,
        LAActivatorIPCMessageAvailableProfileNames,
        LAActivatorIPCMessageCurrentProfileName,
        LAActivatorIPCMessageSetCurrentProfileName,
        LAActivatorIPCMessagePreferenceValue,
        LAActivatorIPCMessageSetPreferenceValue,
        LAActivatorIPCMessageCurrentEventMode,
        LAActivatorIPCMessageCurrentEventModeUnderneathLockScreen,
        LAActivatorIPCMessageSupportsUnlockingDeviceToSendEvents,
        LAActivatorIPCMessageCurrentApplicationDisplayIdentifier,
        LAActivatorIPCMessageEventIsHidden,
        LAActivatorIPCMessageEventRequiresAssignment,
        LAActivatorIPCMessageCompatibleModesForEvent,
        LAActivatorIPCMessageEventIsCompatibleWithMode,
        LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend,
        LAActivatorIPCMessageAssignmentWarningForEvent,
        LAActivatorIPCMessageEventIsUnprotected,
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
        LAActivatorIPCMessageListenerSmallIconData,
        LAActivatorIPCMessageRequestListenerRemoval,
        LAActivatorIPCMessageRemoveEvent,
#if LA_TESTING
        LAActivatorIPCMessageTesting,
#endif
    ];
}

- (NSDictionary *)handleMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if (![messageName isKindOfClass:NSString.class] || ![userInfo isKindOfClass:NSDictionary.class]) {
        return [LAActivatorIPCCodec replyWithOK:NO value:nil];
    }

    NSDictionary *reply = [self handleTestingMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleRegistryMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleAssignmentMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleRuntimeMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleDispatchMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleEventMetadataMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleListenerMetadataMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }
    reply = [self handleLocalizationMessageNamed:messageName withUserInfo:userInfo];
    if (reply) {
        return reply;
    }

    return [LAActivatorIPCCodec replyWithOK:NO value:nil];
}

#pragma mark - Message Handling

- (NSDictionary *)handleTestingMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
#if LA_TESTING
    if ([messageName isEqualToString:LAActivatorIPCMessageTesting]) {
        return [LAActivatorTestSupport handleCommandWithUserInfo:userInfo activator:_activator];
    }
#endif
    return nil;
}

- (NSDictionary *)handleRegistryMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableEventNames]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.availableEventNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasEvent]) {
        NSString *eventName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator hasEventWithName:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableListenerNames]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.availableListenerNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasListener]) {
        NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator hasListenerWithName:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageHasSeenListener]) {
        NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator hasSeenListenerWithName:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAvailableProfileNames]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.availableProfileNames];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentProfileName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.currentProfileName ?: @""];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetCurrentProfileName]) {
        NSString *profileName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyProfileName];
        BOOL changed = [_activator la_setCurrentProfileName:profileName];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessagePreferenceValue]) {
        NSString *preferenceKey = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyPreferenceKey];
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator _getObjectForPreference:preferenceKey]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetPreferenceValue]) {
        NSString *preferenceKey = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyPreferenceKey];
        id preferenceValue = [LAActivatorIPCCodec propertyListValue:userInfo[LAActivatorIPCKeyPreferenceValue]];
        [_activator _setObject:preferenceValue forPreference:preferenceKey];
        return [LAActivatorIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleAssignmentMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignedListenerNames]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator assignedListenerNamesForEvent:event]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventsAssignedToListener]) {
        NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        NSArray *events = [_activator eventsAssignedToListenerWithName:listenerName];
        return [LAActivatorIPCCodec replyWithOK:YES value:[LAActivatorIPCCodec eventDictionariesWithEvents:events]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        NSArray *listenerNames = [LAActivatorIPCCodec stringArrayInUserInfo:userInfo
                                                                     forKey:LAActivatorIPCKeyListenerNames];
        BOOL changed = [_activator la_assignEventAndNotifyIfChanged:event toListenersWithNames:listenerNames];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAddListenerAssignment]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        BOOL changed = [_activator la_addListenerAssignmentAndNotifyIfChanged:listenerName toEvent:event];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoveListenerAssignment]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
        BOOL changed = [_activator la_removeListenerAssignmentAndNotifyIfChanged:listenerName fromEvent:event];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageUnassignEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        BOOL changed = [_activator la_unassignEventAndNotifyIfChanged:event];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageApplicationIsBlacklisted]) {
        NSString *displayIdentifier = [LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                     forKey:LAActivatorIPCKeyDisplayIdentifier];
        BOOL blacklisted = [_activator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(blacklisted)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSetApplicationBlacklisted]) {
        NSString *displayIdentifier = [LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                     forKey:LAActivatorIPCKeyDisplayIdentifier];
        BOOL changed =
            [_activator la_setApplicationWithDisplayIdentifier:displayIdentifier
                                                 isBlacklisted:[userInfo[LAActivatorIPCKeyBlacklisted] boolValue]];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(changed)];
    }
    return nil;
}

- (NSDictionary *)handleRuntimeMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentEventMode]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.currentEventMode ?: @""];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentEventModeUnderneathLockScreen]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.currentEventModeUnderneathLockScreen ?: @""];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageSupportsUnlockingDeviceToSendEvents]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@(_activator.supportsUnlockingDeviceToSendEvents)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCurrentApplicationDisplayIdentifier]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:_activator.displayIdentifierForCurrentApplication ?: @""];
    }
    return nil;
}

- (NSDictionary *)handleDispatchMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAssignedEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendEventToListener:event];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchEventToListeners]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendEvent:event
            toListenersWithNames:[LAActivatorIPCCodec
                                     uniqueOrderedStringArrayInUserInfo:userInfo
                                                                 forKey:LAActivatorIPCKeyListenerNames]];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAssignedAbortEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendAbortToListener:event];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchAbortEventToListeners]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendAbortEvent:event
              toListenersWithNames:[LAActivatorIPCCodec
                                       uniqueOrderedStringArrayInUserInfo:userInfo
                                                                   forKey:LAActivatorIPCKeyListenerNames]];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchPreviewEvent]) {
        [_activator
            sendPreviewEventToListenerWithName:[LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                              forKey:LAActivatorIPCKeyListenerName]];
        return [LAActivatorIPCCodec replyWithOK:YES value:nil];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageDispatchDeactivateEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendDeactivateEventToListeners:event];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoteListenerReceiveEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        NSString *targetListenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                      forKey:LAActivatorIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator la_sendEvent:event directlyToListenerWithName:targetListenerName abort:NO];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoteListenerAbortEvent]) {
        LAEvent *event = [LAActivatorIPCCodec eventWithUserInfo:userInfo];
        NSString *targetListenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                      forKey:LAActivatorIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [LAActivatorIPCCodec replyWithOK:NO value:nil];
        }
        [_activator la_sendEvent:event directlyToListenerWithName:targetListenerName abort:YES];
        return [LAActivatorIPCCodec eventReplyWithEvent:event];
    }
    return nil;
}

- (NSDictionary *)handleEventMetadataMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    NSString *eventMode = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventMode];
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsHidden]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator eventWithNameIsHidden:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventRequiresAssignment]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator eventWithNameRequiresAssignment:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForEvent]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator compatibleModesForEventWithName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsCompatibleWithMode]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator eventWithName:eventName isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator eventWithNameSupportsUnlockingDeviceToSend:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageAssignmentWarningForEvent]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator assignmentWarningForEventWithName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventIsUnprotected]) {
        id<LAEventDataSource> dataSource = [_activator eventDataSourceForEventName:eventName];
        BOOL unprotected = dataSource && [dataSource respondsToSelector:@selector(eventWithNameIsUnprotected:)] &&
                           [dataSource eventWithNameIsUnprotected:eventName];
        return [LAActivatorIPCCodec replyWithOK:YES value:@(unprotected)];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsRemoval]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator eventWithNameSupportsRemoval:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageEventSupportsConfiguration]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator eventWithNameSupportsConfiguration:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRemoveEvent]) {
        [_activator removeEventWithName:eventName];
        return [LAActivatorIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleListenerMetadataMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
    NSString *eventMode = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventMode];
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerInfoDictionaryValue]) {
        id value = [_activator
            infoDictionaryValueOfKey:[LAActivatorIPCCodec stringInUserInfo:userInfo
                                                                    forKey:LAActivatorIPCKeyInfoDictionaryKey]
                 forListenerWithName:listenerName];
        id propertyListValue = [LAActivatorIPCCodec propertyListValue:value];
        return [LAActivatorIPCCodec replyWithOK:propertyListValue != nil value:propertyListValue];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerRequiresAssignment]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerWithNameRequiresAssignment:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageCompatibleModesForListener]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:[_activator compatibleEventModesForListenerWithName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithMode]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerWithName:listenerName
                                                          isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerIsCompatibleWithEvent]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerWithName:listenerName
                                                     isCompatibleWithEventName:eventName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNeedsPoweredDisplay]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerWithNameNeedsPoweredDisplay:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageExclusiveAssignmentGroupsForListener]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:[_activator exclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerNamesAreMutuallyCompatible]) {
        NSArray *listenerNames = [LAActivatorIPCCodec stringArrayInUserInfo:userInfo
                                                                     forKey:LAActivatorIPCKeyListenerNames];
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerNamesAreMutuallyCompatible:listenerNames])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsRemoval]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:@([_activator listenerWithNameSupportsRemoval:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSupportsConfiguration]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:@([_activator listenerWithNameSupportsConfiguration:listenerName])];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageListenerSmallIconData]) {
        CGFloat scale = [userInfo[LAActivatorIPCKeyScale] doubleValue];
        NSData *data = [_activator la_smallIconDataForListenerName:listenerName scale:&scale];
        return [LAActivatorIPCCodec smallIconDataReplyWithData:data scale:scale];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageRequestListenerRemoval]) {
        [_activator requestRemovalForListenerWithName:listenerName];
        return [LAActivatorIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleLocalizationMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyEventName];
    NSString *listenerName = [LAActivatorIPCCodec stringInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerName];
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForEventName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedTitleForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedTitleForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedTitleForListenerNames]) {
        NSArray *listenerNames =
            [LAActivatorIPCCodec uniqueOrderedStringArrayInUserInfo:userInfo forKey:LAActivatorIPCKeyListenerNames];
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedTitleForListenerNames:listenerNames]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForEventName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedGroupForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedGroupForListenerName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedGroupForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForEventName]) {
        return [LAActivatorIPCCodec replyWithOK:YES value:[_activator localizedDescriptionForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAActivatorIPCMessageLocalizedDescriptionForListenerName]) {
        return [LAActivatorIPCCodec replyWithOK:YES
                                          value:[_activator localizedDescriptionForListenerName:listenerName]];
    }
    return nil;
}

@end
