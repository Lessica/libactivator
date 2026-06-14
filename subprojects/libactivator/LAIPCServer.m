//
//  LAIPCServer.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivator+Private.h"
#import "LAIPC.h"
#import "LAIPCCodec.h"
#if DEBUG
#import "LAActivatorTestSupport.h"
#endif

#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LAIPCServer ()
@property(nonatomic, strong) LAActivator *activator;
@property(nonatomic, strong) CPDistributedMessagingCenter *center;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@end

@implementation LAIPCServer

#pragma mark - Lifecycle

- (instancetype)initWithActivator:(LAActivator *)activator {
    self = [super init];
    if (self) {
        _activator = activator;
        _center = [CPDistributedMessagingCenter centerNamed:LAIPCServerName];
    }
    return self;
}

#pragma mark - Server

- (void)start {
    if (self.started) {
        return;
    }

    for (NSString *messageName in [self registeredMessageNames]) {
        [self.center registerForMessageName:messageName
                                     target:self
                                   selector:@selector(handleMessageNamed:withUserInfo:)];
    }
    [self.center runServerOnCurrentThread];
    self.started = YES;
}

- (NSArray *)registeredMessageNames {
    return @[
        LAIPCMessageAvailableEventNames,
        LAIPCMessageHasEvent,
        LAIPCMessageAvailableListenerNames,
        LAIPCMessageHasListener,
        LAIPCMessageHasSeenListener,
        LAIPCMessageAssignedListenerNames,
        LAIPCMessageEventsAssignedToListener,
        LAIPCMessageAssignEvent,
        LAIPCMessageAddListenerAssignment,
        LAIPCMessageRemoveListenerAssignment,
        LAIPCMessageUnassignEvent,
        LAIPCMessageApplicationIsBlacklisted,
        LAIPCMessageSetApplicationBlacklisted,
        LAIPCMessageAvailableProfileNames,
        LAIPCMessageCurrentProfileName,
        LAIPCMessageSetCurrentProfileName,
        LAIPCMessagePreferenceValue,
        LAIPCMessageSetPreferenceValue,
        LAIPCMessageCurrentEventMode,
        LAIPCMessageCurrentEventModeUnderneathLockScreen,
        LAIPCMessageSupportsUnlockingDeviceToSendEvents,
        LAIPCMessageCurrentApplicationDisplayIdentifier,
        LAIPCMessageEventIsHidden,
        LAIPCMessageEventRequiresAssignment,
        LAIPCMessageCompatibleModesForEvent,
        LAIPCMessageEventIsCompatibleWithMode,
        LAIPCMessageEventSupportsUnlockingDeviceToSend,
        LAIPCMessageAssignmentWarningForEvent,
        LAIPCMessageEventIsUnprotected,
        LAIPCMessageEventSupportsRemoval,
        LAIPCMessageEventSupportsConfiguration,
        LAIPCMessageListenerInfoDictionaryValue,
        LAIPCMessageListenerRequiresAssignment,
        LAIPCMessageCompatibleModesForListener,
        LAIPCMessageListenerIsCompatibleWithMode,
        LAIPCMessageListenerIsCompatibleWithEvent,
        LAIPCMessageListenerNeedsPoweredDisplay,
        LAIPCMessageExclusiveAssignmentGroupsForListener,
        LAIPCMessageListenerNamesAreMutuallyCompatible,
        LAIPCMessageListenerSupportsRemoval,
        LAIPCMessageListenerSupportsConfiguration,
        LAIPCMessageLocalizedTitleForEventName,
        LAIPCMessageLocalizedTitleForListenerName,
        LAIPCMessageLocalizedTitleForListenerNames,
        LAIPCMessageLocalizedGroupForEventName,
        LAIPCMessageLocalizedGroupForListenerName,
        LAIPCMessageLocalizedDescriptionForEventName,
        LAIPCMessageLocalizedDescriptionForListenerName,
        LAIPCMessageDispatchAssignedEvent,
        LAIPCMessageDispatchEventToListeners,
        LAIPCMessageDispatchAssignedAbortEvent,
        LAIPCMessageDispatchAbortEventToListeners,
        LAIPCMessageDispatchPreviewEvent,
        LAIPCMessageDispatchDeactivateEvent,
        LAIPCMessageRemoteListenerReceiveEvent,
        LAIPCMessageRemoteListenerAbortEvent,
        LAIPCMessageListenerSmallIconData,
        LAIPCMessageRequestListenerRemoval,
        LAIPCMessageRemoveEvent,
#if DEBUG
        LAIPCMessageTesting,
#endif
#if DEBUG
        LAIPCMessageEventDispatchCounts,
        LAIPCMessageListenerReceiveCounts,
        LAIPCMessageEventAbortCounts,
        LAIPCMessageListenerAbortCounts,
        LAIPCMessageResetDispatchCounts,
#endif
    ];
}

- (NSDictionary *)handleMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if (![messageName isKindOfClass:NSString.class] || ![userInfo isKindOfClass:NSDictionary.class]) {
        return [LAIPCCodec replyWithOK:NO value:nil];
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

    return [LAIPCCodec replyWithOK:NO value:nil];
}

#pragma mark - Message Handling

- (NSDictionary *)handleTestingMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
#if DEBUG
    if ([messageName isEqualToString:LAIPCMessageTesting]) {
        return [LAActivatorTestSupport handleCommandWithUserInfo:userInfo activator:_activator];
    }
#endif
    return nil;
}

- (NSDictionary *)handleRegistryMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAIPCMessageAvailableEventNames]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.availableEventNames];
    }
    if ([messageName isEqualToString:LAIPCMessageHasEvent]) {
        NSString *eventName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventName];
        return [LAIPCCodec replyWithOK:YES value:@([_activator hasEventWithName:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageAvailableListenerNames]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.availableListenerNames];
    }
    if ([messageName isEqualToString:LAIPCMessageHasListener]) {
        NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        return [LAIPCCodec replyWithOK:YES value:@([_activator hasListenerWithName:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageHasSeenListener]) {
        NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        return [LAIPCCodec replyWithOK:YES value:@([_activator hasSeenListenerWithName:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageAvailableProfileNames]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.availableProfileNames];
    }
    if ([messageName isEqualToString:LAIPCMessageCurrentProfileName]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.currentProfileName ?: @""];
    }
    if ([messageName isEqualToString:LAIPCMessageSetCurrentProfileName]) {
        NSString *profileName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyProfileName];
        BOOL changed = [_activator la_setCurrentProfileName:profileName];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAIPCMessagePreferenceValue]) {
        NSString *preferenceKey = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyPreferenceKey];
        return [LAIPCCodec replyWithOK:YES value:[_activator _getObjectForPreference:preferenceKey]];
    }
    if ([messageName isEqualToString:LAIPCMessageSetPreferenceValue]) {
        NSString *preferenceKey = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyPreferenceKey];
        id preferenceValue = [LAIPCCodec propertyListValue:userInfo[LAIPCKeyPreferenceValue]];
        [_activator _setObject:preferenceValue forPreference:preferenceKey];
        return [LAIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleAssignmentMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAIPCMessageAssignedListenerNames]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        return [LAIPCCodec replyWithOK:YES value:[_activator assignedListenerNamesForEvent:event]];
    }
    if ([messageName isEqualToString:LAIPCMessageEventsAssignedToListener]) {
        NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        NSArray *events = [_activator eventsAssignedToListenerWithName:listenerName];
        return [LAIPCCodec replyWithOK:YES value:[LAIPCCodec eventDictionariesWithEvents:events]];
    }
    if ([messageName isEqualToString:LAIPCMessageAssignEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        NSArray *listenerNames = [LAIPCCodec stringArrayInUserInfo:userInfo forKey:LAIPCKeyListenerNames];
        BOOL changed = [_activator la_assignEventAndNotifyIfChanged:event toListenersWithNames:listenerNames];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAIPCMessageAddListenerAssignment]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        BOOL changed = [_activator la_addListenerAssignmentAndNotifyIfChanged:listenerName toEvent:event];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAIPCMessageRemoveListenerAssignment]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        BOOL changed = [_activator la_removeListenerAssignmentAndNotifyIfChanged:listenerName fromEvent:event];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAIPCMessageUnassignEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        BOOL changed = [_activator la_unassignEventAndNotifyIfChanged:event];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    if ([messageName isEqualToString:LAIPCMessageApplicationIsBlacklisted]) {
        NSString *displayIdentifier = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyDisplayIdentifier];
        BOOL blacklisted = [_activator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier];
        return [LAIPCCodec replyWithOK:YES value:@(blacklisted)];
    }
    if ([messageName isEqualToString:LAIPCMessageSetApplicationBlacklisted]) {
        NSString *displayIdentifier = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyDisplayIdentifier];
        BOOL changed = [_activator la_setApplicationWithDisplayIdentifier:displayIdentifier
                                                            isBlacklisted:[userInfo[LAIPCKeyBlacklisted] boolValue]];
        return [LAIPCCodec replyWithOK:YES value:@(changed)];
    }
    return nil;
}

- (NSDictionary *)handleRuntimeMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAIPCMessageCurrentEventMode]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.currentEventMode ?: @""];
    }
    if ([messageName isEqualToString:LAIPCMessageCurrentEventModeUnderneathLockScreen]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.currentEventModeUnderneathLockScreen ?: @""];
    }
    if ([messageName isEqualToString:LAIPCMessageSupportsUnlockingDeviceToSendEvents]) {
        return [LAIPCCodec replyWithOK:YES value:@(_activator.supportsUnlockingDeviceToSendEvents)];
    }
    if ([messageName isEqualToString:LAIPCMessageCurrentApplicationDisplayIdentifier]) {
        return [LAIPCCodec replyWithOK:YES value:_activator.displayIdentifierForCurrentApplication ?: @""];
    }
#if DEBUG
    if ([messageName isEqualToString:LAIPCMessageEventDispatchCounts]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator la_eventDispatchCounts]];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerReceiveCounts]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator la_listenerReceiveCounts]];
    }
    if ([messageName isEqualToString:LAIPCMessageEventAbortCounts]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator la_eventAbortCounts]];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerAbortCounts]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator la_listenerAbortCounts]];
    }
    if ([messageName isEqualToString:LAIPCMessageResetDispatchCounts]) {
        [_activator la_resetDispatchCounts];
        return [LAIPCCodec replyWithOK:YES value:nil];
    }
#endif
    return nil;
}

- (NSDictionary *)handleDispatchMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    if ([messageName isEqualToString:LAIPCMessageDispatchAssignedEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendEventToListener:event];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageDispatchEventToListeners]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendEvent:event
            toListenersWithNames:[LAIPCCodec uniqueOrderedStringArrayInUserInfo:userInfo forKey:LAIPCKeyListenerNames]];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageDispatchAssignedAbortEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendAbortToListener:event];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageDispatchAbortEventToListeners]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendAbortEvent:event
              toListenersWithNames:[LAIPCCodec uniqueOrderedStringArrayInUserInfo:userInfo
                                                                           forKey:LAIPCKeyListenerNames]];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageDispatchPreviewEvent]) {
        [_activator sendPreviewEventToListenerWithName:[LAIPCCodec stringInUserInfo:userInfo
                                                                             forKey:LAIPCKeyListenerName]];
        return [LAIPCCodec replyWithOK:YES value:nil];
    }
    if ([messageName isEqualToString:LAIPCMessageDispatchDeactivateEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        if (!event) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator sendDeactivateEventToListeners:event];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageRemoteListenerReceiveEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        NSString *targetListenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator la_sendEvent:event directlyToListenerWithName:targetListenerName abort:NO];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    if ([messageName isEqualToString:LAIPCMessageRemoteListenerAbortEvent]) {
        LAEvent *event = [LAIPCCodec eventWithUserInfo:userInfo];
        NSString *targetListenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
        if (!event || targetListenerName.length == 0) {
            return [LAIPCCodec replyWithOK:NO value:nil];
        }
        [_activator la_sendEvent:event directlyToListenerWithName:targetListenerName abort:YES];
        return [LAIPCCodec eventReplyWithEvent:event];
    }
    return nil;
}

- (NSDictionary *)handleEventMetadataMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventName];
    NSString *eventMode = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventMode];
    if ([messageName isEqualToString:LAIPCMessageEventIsHidden]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator eventWithNameIsHidden:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageEventRequiresAssignment]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator eventWithNameRequiresAssignment:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageCompatibleModesForEvent]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator compatibleModesForEventWithName:eventName]];
    }
    if ([messageName isEqualToString:LAIPCMessageEventIsCompatibleWithMode]) {
        return [LAIPCCodec replyWithOK:YES
                                 value:@([_activator eventWithName:eventName isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAIPCMessageEventSupportsUnlockingDeviceToSend]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator eventWithNameSupportsUnlockingDeviceToSend:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageAssignmentWarningForEvent]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator assignmentWarningForEventWithName:eventName]];
    }
    if ([messageName isEqualToString:LAIPCMessageEventIsUnprotected]) {
        id<LAEventDataSource> dataSource = [_activator eventDataSourceForEventName:eventName];
        BOOL unprotected = dataSource && [dataSource respondsToSelector:@selector(eventWithNameIsUnprotected:)] &&
                           [dataSource eventWithNameIsUnprotected:eventName];
        return [LAIPCCodec replyWithOK:YES value:@(unprotected)];
    }
    if ([messageName isEqualToString:LAIPCMessageEventSupportsRemoval]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator eventWithNameSupportsRemoval:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageEventSupportsConfiguration]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator eventWithNameSupportsConfiguration:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageRemoveEvent]) {
        [_activator removeEventWithName:eventName];
        return [LAIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleListenerMetadataMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventName];
    NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
    NSString *eventMode = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventMode];
    if ([messageName isEqualToString:LAIPCMessageListenerInfoDictionaryValue]) {
        id value = [_activator infoDictionaryValueOfKey:[LAIPCCodec stringInUserInfo:userInfo
                                                                              forKey:LAIPCKeyInfoDictionaryKey]
                                    forListenerWithName:listenerName];
        id propertyListValue = [LAIPCCodec propertyListValue:value];
        return [LAIPCCodec replyWithOK:propertyListValue != nil value:propertyListValue];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerRequiresAssignment]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator listenerWithNameRequiresAssignment:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageCompatibleModesForListener]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator compatibleEventModesForListenerWithName:listenerName]];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerIsCompatibleWithMode]) {
        return [LAIPCCodec replyWithOK:YES
                                 value:@([_activator listenerWithName:listenerName isCompatibleWithMode:eventMode])];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerIsCompatibleWithEvent]) {
        return [LAIPCCodec replyWithOK:YES
                                 value:@([_activator listenerWithName:listenerName
                                            isCompatibleWithEventName:eventName])];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerNeedsPoweredDisplay]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator listenerWithNameNeedsPoweredDisplay:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageExclusiveAssignmentGroupsForListener]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator exclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerNamesAreMutuallyCompatible]) {
        NSArray *listenerNames = [LAIPCCodec stringArrayInUserInfo:userInfo forKey:LAIPCKeyListenerNames];
        return [LAIPCCodec replyWithOK:YES value:@([_activator listenerNamesAreMutuallyCompatible:listenerNames])];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerSupportsRemoval]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator listenerWithNameSupportsRemoval:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerSupportsConfiguration]) {
        return [LAIPCCodec replyWithOK:YES value:@([_activator listenerWithNameSupportsConfiguration:listenerName])];
    }
    if ([messageName isEqualToString:LAIPCMessageListenerSmallIconData]) {
        CGFloat scale = [userInfo[LAIPCKeyScale] doubleValue];
        NSData *data = [_activator la_smallIconDataForListenerName:listenerName scale:&scale];
        return [LAIPCCodec smallIconDataReplyWithData:data scale:scale];
    }
    if ([messageName isEqualToString:LAIPCMessageRequestListenerRemoval]) {
        [_activator requestRemovalForListenerWithName:listenerName];
        return [LAIPCCodec replyWithOK:YES value:nil];
    }
    return nil;
}

- (NSDictionary *)handleLocalizationMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo {
    NSString *eventName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyEventName];
    NSString *listenerName = [LAIPCCodec stringInUserInfo:userInfo forKey:LAIPCKeyListenerName];
    if ([messageName isEqualToString:LAIPCMessageLocalizedTitleForEventName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedTitleForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedTitleForListenerName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedTitleForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedTitleForListenerNames]) {
        NSArray *listenerNames = [LAIPCCodec uniqueOrderedStringArrayInUserInfo:userInfo forKey:LAIPCKeyListenerNames];
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedTitleForListenerNames:listenerNames]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedGroupForEventName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedGroupForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedGroupForListenerName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedGroupForListenerName:listenerName]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedDescriptionForEventName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedDescriptionForEventName:eventName]];
    }
    if ([messageName isEqualToString:LAIPCMessageLocalizedDescriptionForListenerName]) {
        return [LAIPCCodec replyWithOK:YES value:[_activator localizedDescriptionForListenerName:listenerName]];
    }
    return nil;
}

@end
