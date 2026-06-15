//
//  LAIPC.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAIPC.h"

NSString *const LAIPCServerName = @"libactivator.springboard";

NSString *const LAIPCMessageAvailableEventNames = @"libactivator.request.available-event-names";
NSString *const LAIPCMessageHasEvent = @"libactivator.request.has-event";
NSString *const LAIPCMessageAvailableListenerNames = @"libactivator.request.available-listener-names";
NSString *const LAIPCMessageHasListener = @"libactivator.request.has-listener";
NSString *const LAIPCMessageHasSeenListener = @"libactivator.request.has-seen-listener";
NSString *const LAIPCMessageAssignedListenerNames = @"libactivator.request.assigned-listener-names";
NSString *const LAIPCMessageEventsAssignedToListener = @"libactivator.request.events-assigned-to-listener";
NSString *const LAIPCMessageAssignEvent = @"libactivator.request.assign-event";
NSString *const LAIPCMessageAddListenerAssignment = @"libactivator.request.add-listener-assignment";
NSString *const LAIPCMessageRemoveListenerAssignment = @"libactivator.request.remove-listener-assignment";
NSString *const LAIPCMessageUnassignEvent = @"libactivator.request.unassign-event";
NSString *const LAIPCMessageApplicationIsBlacklisted = @"libactivator.request.application-is-blacklisted";
NSString *const LAIPCMessageSetApplicationBlacklisted = @"libactivator.request.set-application-blacklisted";
NSString *const LAIPCMessageAvailableProfileNames = @"libactivator.request.available-profile-names";
NSString *const LAIPCMessageCurrentProfileName = @"libactivator.request.current-profile-name";
NSString *const LAIPCMessageSetCurrentProfileName = @"libactivator.request.set-current-profile-name";
NSString *const LAIPCMessagePreferenceValue = @"libactivator.request.preference-value";
NSString *const LAIPCMessageSetPreferenceValue = @"libactivator.request.set-preference-value";
NSString *const LAIPCMessageCurrentEventMode = @"libactivator.request.current-event-mode";
NSString *const LAIPCMessageCurrentEventModeUnderneathLockScreen =
    @"libactivator.request.current-event-mode-underneath-lock-screen";
NSString *const LAIPCMessageSupportsUnlockingDeviceToSendEvents =
    @"libactivator.request.supports-unlocking-device-to-send-events";
NSString *const LAIPCMessageCurrentApplicationDisplayIdentifier =
    @"libactivator.request.current-application-display-identifier";

NSString *const LAIPCMessageEventIsHidden = @"libactivator.request.event-is-hidden";
NSString *const LAIPCMessageEventRequiresAssignment = @"libactivator.request.event-requires-assignment";
NSString *const LAIPCMessageCompatibleModesForEvent = @"libactivator.request.compatible-modes-for-event";
NSString *const LAIPCMessageEventIsCompatibleWithMode = @"libactivator.request.event-is-compatible-with-mode";
NSString *const LAIPCMessageEventSupportsUnlockingDeviceToSend =
    @"libactivator.request.event-supports-unlocking-device-to-send";
NSString *const LAIPCMessageAssignmentWarningForEvent = @"libactivator.request.assignment-warning-for-event";
NSString *const LAIPCMessageEventIsUnprotected = @"libactivator.request.event-is-unprotected";
NSString *const LAIPCMessageEventSupportsRemoval = @"libactivator.request.event-supports-removal";
NSString *const LAIPCMessageEventSupportsConfiguration = @"libactivator.request.event-supports-configuration";

NSString *const LAIPCMessageListenerInfoDictionaryValue = @"libactivator.request.listener-info-dictionary-value";
NSString *const LAIPCMessageListenerRequiresAssignment = @"libactivator.request.listener-requires-assignment";
NSString *const LAIPCMessageCompatibleModesForListener = @"libactivator.request.compatible-modes-for-listener";
NSString *const LAIPCMessageListenerIsCompatibleWithMode = @"libactivator.request.listener-is-compatible-with-mode";
NSString *const LAIPCMessageListenerIsCompatibleWithEvent = @"libactivator.request.listener-is-compatible-with-event";
NSString *const LAIPCMessageListenerNeedsPoweredDisplay = @"libactivator.request.listener-needs-powered-display";
NSString *const LAIPCMessageExclusiveAssignmentGroupsForListener =
    @"libactivator.request.exclusive-assignment-groups-for-listener";
NSString *const LAIPCMessageListenerNamesAreMutuallyCompatible =
    @"libactivator.request.listener-names-are-mutually-compatible";
NSString *const LAIPCMessageListenerSupportsRemoval = @"libactivator.request.listener-supports-removal";
NSString *const LAIPCMessageListenerSupportsConfiguration = @"libactivator.request.listener-supports-configuration";

NSString *const LAIPCMessageLocalizedTitleForEventName = @"libactivator.request.localized-title-for-event-name";
NSString *const LAIPCMessageLocalizedTitleForListenerName = @"libactivator.request.localized-title-for-listener-name";
NSString *const LAIPCMessageLocalizedTitleForListenerNames = @"libactivator.request.localized-title-for-listener-names";
NSString *const LAIPCMessageLocalizedGroupForEventName = @"libactivator.request.localized-group-for-event-name";
NSString *const LAIPCMessageLocalizedGroupForListenerName = @"libactivator.request.localized-group-for-listener-name";
NSString *const LAIPCMessageLocalizedDescriptionForEventName =
    @"libactivator.request.localized-description-for-event-name";
NSString *const LAIPCMessageLocalizedDescriptionForListenerName =
    @"libactivator.request.localized-description-for-listener-name";

NSString *const LAIPCMessageDispatchAssignedEvent = @"libactivator.request.dispatch-assigned-event";
NSString *const LAIPCMessageDispatchEventToListeners = @"libactivator.request.dispatch-event-to-listeners";
NSString *const LAIPCMessageDispatchAssignedAbortEvent = @"libactivator.request.dispatch-assigned-abort-event";
NSString *const LAIPCMessageDispatchAbortEventToListeners = @"libactivator.request.dispatch-abort-event-to-listeners";
NSString *const LAIPCMessageDispatchPreviewEvent = @"libactivator.request.dispatch-preview-event";
NSString *const LAIPCMessageDispatchDeactivateEvent = @"libactivator.request.dispatch-deactivate-event";
NSString *const LAIPCMessageRemoteListenerReceiveEvent = @"libactivator.request.remote-listener-receive-event";
NSString *const LAIPCMessageRemoteListenerAbortEvent = @"libactivator.request.remote-listener-abort-event";
NSString *const LAIPCMessageListenerSmallIconData = @"libactivator.request.listener-small-icon-data";
NSString *const LAIPCMessageRequestListenerRemoval = @"libactivator.request.listener-request-removal";
NSString *const LAIPCMessageRemoveEvent = @"libactivator.request.remove-event";

#if LIBACTIVATOR_TEST_SUPPORT
NSString *const LAIPCMessageTesting = @"libactivator.testing";
NSString *const LAIPCTestingCommandPing = @"ping";
NSString *const LAIPCTestingCommandCleanup = @"cleanup";
NSString *const LAIPCTestingCommandRun = @"run";
NSString *const LAIPCTestingCommandRunRuntimeInput = @"run-runtime-input";
NSString *const LAIPCTestingCommandRunDeviceRuntime = @"run-device-runtime";
NSString *const LAIPCTestingCommandRuntimeState = @"runtime-state";
NSString *const LAIPCTestingCommandPrepareUserInfoProbe = @"prepare-user-info-probe";
NSString *const LAIPCTestingCommandUserInfoProbeResult = @"user-info-probe-result";
#endif

NSString *const LAIPCKeyOK = @"OK";
NSString *const LAIPCKeyValue = @"Value";
NSString *const LAIPCKeyEventName = @"EventName";
NSString *const LAIPCKeyEventMode = @"EventMode";
NSString *const LAIPCKeyEventHandled = @"EventHandled";
NSString *const LAIPCKeyEventUserInfo = @"UserInfo";
NSString *const LAIPCKeyListenerName = @"ListenerName";
NSString *const LAIPCKeyListenerNames = @"ListenerNames";
NSString *const LAIPCKeyDisplayIdentifier = @"DisplayIdentifier";
NSString *const LAIPCKeyBlacklisted = @"Blacklisted";
NSString *const LAIPCKeyProfileName = @"ProfileName";
NSString *const LAIPCKeyPreferenceKey = @"PreferenceKey";
NSString *const LAIPCKeyPreferenceValue = @"PreferenceValue";
NSString *const LAIPCKeyInfoDictionaryKey = @"InfoDictionaryKey";
NSString *const LAIPCKeyScale = @"Scale";

#if LIBACTIVATOR_TEST_SUPPORT
NSString *const LAIPCKeyTestingCommand = @"TestingCommand";
NSString *const LAIPCKeyTestingSuites = @"TestingSuites";
NSString *const LAIPCKeyTestingFailures = @"TestingFailures";
NSString *const LAIPCKeyTestingSkipped = @"TestingSkipped";
NSString *const LAIPCKeyTestingCaseCount = @"TestingCaseCount";
NSString *const LAIPCKeyTestingPassCount = @"TestingPassCount";
NSString *const LAIPCKeyTestingFailureCount = @"TestingFailureCount";
NSString *const LAIPCKeyTestingSkipCount = @"TestingSkipCount";
#endif

#if LIBACTIVATOR_TEST_SUPPORT
NSString *const LAIPCMessageEventDispatchCounts = @"libactivator.request.event-dispatch-counts";
NSString *const LAIPCMessageListenerReceiveCounts = @"libactivator.request.listener-receive-counts";
NSString *const LAIPCMessageEventAbortCounts = @"libactivator.request.event-abort-counts";
NSString *const LAIPCMessageListenerAbortCounts = @"libactivator.request.listener-abort-counts";
NSString *const LAIPCMessageResetDispatchCounts = @"libactivator.request.reset-dispatch-counts";
#endif
