#import "LAActivatorIPC.h"

NSString *const LAActivatorIPCServerName = @"libactivator.springboard";

NSString *const LAActivatorIPCMessageAvailableEventNames = @"libactivator.request.available-event-names";
NSString *const LAActivatorIPCMessageHasEvent = @"libactivator.request.has-event";
NSString *const LAActivatorIPCMessageAvailableListenerNames = @"libactivator.request.available-listener-names";
NSString *const LAActivatorIPCMessageHasListener = @"libactivator.request.has-listener";
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

NSString *const LAActivatorIPCKeyOK = @"OK";
NSString *const LAActivatorIPCKeyValue = @"Value";
NSString *const LAActivatorIPCKeyEventName = @"EventName";
NSString *const LAActivatorIPCKeyEventMode = @"EventMode";
NSString *const LAActivatorIPCKeyListenerName = @"ListenerName";
NSString *const LAActivatorIPCKeyListenerNames = @"ListenerNames";
NSString *const LAActivatorIPCKeyDisplayIdentifier = @"DisplayIdentifier";
NSString *const LAActivatorIPCKeyBlacklisted = @"Blacklisted";
NSString *const LAActivatorIPCKeyProfileName = @"ProfileName";
NSString *const LAActivatorIPCKeyInfoDictionaryKey = @"InfoDictionaryKey";
