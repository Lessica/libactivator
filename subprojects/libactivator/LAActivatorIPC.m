#import "LAActivatorIPC.h"

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCServerName = @"libactivator.springboard";

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageAvailableEventNames =
    @"libactivator.request.available-event-names";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageHasEvent =
    @"libactivator.request.has-event";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageAvailableListenerNames =
    @"libactivator.request.available-listener-names";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageHasListener =
    @"libactivator.request.has-listener";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageAssignedListenerNames =
    @"libactivator.request.assigned-listener-names";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventsAssignedToListener =
    @"libactivator.request.events-assigned-to-listener";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageAssignEvent =
    @"libactivator.request.assign-event";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageUnassignEvent =
    @"libactivator.request.unassign-event";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageApplicationIsBlacklisted =
    @"libactivator.request.application-is-blacklisted";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageSetApplicationBlacklisted =
    @"libactivator.request.set-application-blacklisted";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageAvailableProfileNames =
    @"libactivator.request.available-profile-names";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageCurrentProfileName =
    @"libactivator.request.current-profile-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageSetCurrentProfileName =
    @"libactivator.request.set-current-profile-name";

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventIsHidden =
    @"libactivator.request.event-is-hidden";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventRequiresAssignment =
    @"libactivator.request.event-requires-assignment";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageCompatibleModesForEvent =
    @"libactivator.request.compatible-modes-for-event";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventIsCompatibleWithMode =
    @"libactivator.request.event-is-compatible-with-mode";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend =
    @"libactivator.request.event-supports-unlocking-device-to-send";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventSupportsRemoval =
    @"libactivator.request.event-supports-removal";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageEventSupportsConfiguration =
    @"libactivator.request.event-supports-configuration";

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerInfoDictionaryValue =
    @"libactivator.request.listener-info-dictionary-value";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerRequiresAssignment =
    @"libactivator.request.listener-requires-assignment";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageCompatibleModesForListener =
    @"libactivator.request.compatible-modes-for-listener";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerIsCompatibleWithMode =
    @"libactivator.request.listener-is-compatible-with-mode";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerIsCompatibleWithEvent =
    @"libactivator.request.listener-is-compatible-with-event";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerNeedsPoweredDisplay =
    @"libactivator.request.listener-needs-powered-display";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageExclusiveAssignmentGroupsForListener =
    @"libactivator.request.exclusive-assignment-groups-for-listener";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerNamesAreMutuallyCompatible =
    @"libactivator.request.listener-names-are-mutually-compatible";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerSupportsRemoval =
    @"libactivator.request.listener-supports-removal";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageListenerSupportsConfiguration =
    @"libactivator.request.listener-supports-configuration";

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedTitleForEventName =
    @"libactivator.request.localized-title-for-event-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedTitleForListenerName =
    @"libactivator.request.localized-title-for-listener-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedTitleForListenerNames =
    @"libactivator.request.localized-title-for-listener-names";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedGroupForEventName =
    @"libactivator.request.localized-group-for-event-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedGroupForListenerName =
    @"libactivator.request.localized-group-for-listener-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedDescriptionForEventName =
    @"libactivator.request.localized-description-for-event-name";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCMessageLocalizedDescriptionForListenerName =
    @"libactivator.request.localized-description-for-listener-name";

__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyOK = @"OK";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyValue = @"Value";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyEventName = @"EventName";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyEventMode = @"EventMode";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyListenerName = @"ListenerName";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyListenerNames = @"ListenerNames";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyDisplayIdentifier = @"DisplayIdentifier";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyBlacklisted = @"Blacklisted";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyProfileName = @"ProfileName";
__attribute__((visibility("hidden"))) NSString *const LAActivatorIPCKeyInfoDictionaryKey = @"InfoDictionaryKey";
