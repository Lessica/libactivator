//
//  LAActivatorIPC.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorIPC.h"

NSString *const LAActivatorIPCServerName = @"libactivator.springboard";

NSString *const LAActivatorIPCMessageAvailableEventNames = @"libactivator.request.available-event-names";
NSString *const LAActivatorIPCMessageHasEvent = @"libactivator.request.has-event";
NSString *const LAActivatorIPCMessageAvailableListenerNames = @"libactivator.request.available-listener-names";
NSString *const LAActivatorIPCMessageHasListener = @"libactivator.request.has-listener";
NSString *const LAActivatorIPCMessageHasSeenListener = @"libactivator.request.has-seen-listener";
NSString *const LAActivatorIPCMessageAssignedListenerNames = @"libactivator.request.assigned-listener-names";
NSString *const LAActivatorIPCMessageEventsAssignedToListener = @"libactivator.request.events-assigned-to-listener";
NSString *const LAActivatorIPCMessageAssignEvent = @"libactivator.request.assign-event";
NSString *const LAActivatorIPCMessageUnassignEvent = @"libactivator.request.unassign-event";
NSString *const LAActivatorIPCMessageApplicationIsBlacklisted = @"libactivator.request.application-is-blacklisted";
NSString *const LAActivatorIPCMessageSetApplicationBlacklisted = @"libactivator.request.set-application-blacklisted";
NSString *const LAActivatorIPCMessageAvailableProfileNames = @"libactivator.request.available-profile-names";
NSString *const LAActivatorIPCMessageCurrentProfileName = @"libactivator.request.current-profile-name";
NSString *const LAActivatorIPCMessageSetCurrentProfileName = @"libactivator.request.set-current-profile-name";

NSString *const LAActivatorIPCMessageEventIsHidden = @"libactivator.request.event-is-hidden";
NSString *const LAActivatorIPCMessageEventRequiresAssignment = @"libactivator.request.event-requires-assignment";
NSString *const LAActivatorIPCMessageCompatibleModesForEvent = @"libactivator.request.compatible-modes-for-event";
NSString *const LAActivatorIPCMessageEventIsCompatibleWithMode = @"libactivator.request.event-is-compatible-with-mode";
NSString *const LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend =
    @"libactivator.request.event-supports-unlocking-device-to-send";
NSString *const LAActivatorIPCMessageEventSupportsRemoval = @"libactivator.request.event-supports-removal";
NSString *const LAActivatorIPCMessageEventSupportsConfiguration = @"libactivator.request.event-supports-configuration";

NSString *const LAActivatorIPCMessageListenerInfoDictionaryValue =
    @"libactivator.request.listener-info-dictionary-value";
NSString *const LAActivatorIPCMessageListenerRequiresAssignment = @"libactivator.request.listener-requires-assignment";
NSString *const LAActivatorIPCMessageCompatibleModesForListener = @"libactivator.request.compatible-modes-for-listener";
NSString *const LAActivatorIPCMessageListenerIsCompatibleWithMode =
    @"libactivator.request.listener-is-compatible-with-mode";
NSString *const LAActivatorIPCMessageListenerIsCompatibleWithEvent =
    @"libactivator.request.listener-is-compatible-with-event";
NSString *const LAActivatorIPCMessageListenerNeedsPoweredDisplay =
    @"libactivator.request.listener-needs-powered-display";
NSString *const LAActivatorIPCMessageExclusiveAssignmentGroupsForListener =
    @"libactivator.request.exclusive-assignment-groups-for-listener";
NSString *const LAActivatorIPCMessageListenerNamesAreMutuallyCompatible =
    @"libactivator.request.listener-names-are-mutually-compatible";
NSString *const LAActivatorIPCMessageListenerSupportsRemoval = @"libactivator.request.listener-supports-removal";
NSString *const LAActivatorIPCMessageListenerSupportsConfiguration =
    @"libactivator.request.listener-supports-configuration";

NSString *const LAActivatorIPCMessageLocalizedTitleForEventName =
    @"libactivator.request.localized-title-for-event-name";
NSString *const LAActivatorIPCMessageLocalizedTitleForListenerName =
    @"libactivator.request.localized-title-for-listener-name";
NSString *const LAActivatorIPCMessageLocalizedTitleForListenerNames =
    @"libactivator.request.localized-title-for-listener-names";
NSString *const LAActivatorIPCMessageLocalizedGroupForEventName =
    @"libactivator.request.localized-group-for-event-name";
NSString *const LAActivatorIPCMessageLocalizedGroupForListenerName =
    @"libactivator.request.localized-group-for-listener-name";
NSString *const LAActivatorIPCMessageLocalizedDescriptionForEventName =
    @"libactivator.request.localized-description-for-event-name";
NSString *const LAActivatorIPCMessageLocalizedDescriptionForListenerName =
    @"libactivator.request.localized-description-for-listener-name";

NSString *const LAActivatorIPCMessageDispatchAssignedEvent = @"libactivator.request.dispatch-assigned-event";
NSString *const LAActivatorIPCMessageDispatchEventToListeners = @"libactivator.request.dispatch-event-to-listeners";
NSString *const LAActivatorIPCMessageDispatchAssignedAbortEvent = @"libactivator.request.dispatch-assigned-abort-event";
NSString *const LAActivatorIPCMessageDispatchAbortEventToListeners =
    @"libactivator.request.dispatch-abort-event-to-listeners";
NSString *const LAActivatorIPCMessageDispatchPreviewEvent = @"libactivator.request.dispatch-preview-event";
NSString *const LAActivatorIPCMessageDispatchDeactivateEvent = @"libactivator.request.dispatch-deactivate-event";
NSString *const LAActivatorIPCMessageRemoteListenerReceiveEvent = @"libactivator.request.remote-listener-receive-event";
NSString *const LAActivatorIPCMessageRemoteListenerAbortEvent = @"libactivator.request.remote-listener-abort-event";
NSString *const LAActivatorIPCMessageListenerIconData = @"libactivator.request.listener-icon-data";
NSString *const LAActivatorIPCMessageListenerSmallIconData = @"libactivator.request.listener-small-icon-data";
NSString *const LAActivatorIPCMessageRequestListenerRemoval = @"libactivator.request.listener-request-removal";
NSString *const LAActivatorIPCMessageRemoveEvent = @"libactivator.request.remove-event";

NSString *const LAActivatorIPCKeyOK = @"OK";
NSString *const LAActivatorIPCKeyValue = @"Value";
NSString *const LAActivatorIPCKeyEventName = @"EventName";
NSString *const LAActivatorIPCKeyEventMode = @"EventMode";
NSString *const LAActivatorIPCKeyEventHandled = @"EventHandled";
NSString *const LAActivatorIPCKeyEventUserInfo = @"UserInfo";
NSString *const LAActivatorIPCKeyListenerName = @"ListenerName";
NSString *const LAActivatorIPCKeyListenerNames = @"ListenerNames";
NSString *const LAActivatorIPCKeyDisplayIdentifier = @"DisplayIdentifier";
NSString *const LAActivatorIPCKeyBlacklisted = @"Blacklisted";
NSString *const LAActivatorIPCKeyProfileName = @"ProfileName";
NSString *const LAActivatorIPCKeyInfoDictionaryKey = @"InfoDictionaryKey";
NSString *const LAActivatorIPCKeyScale = @"Scale";
