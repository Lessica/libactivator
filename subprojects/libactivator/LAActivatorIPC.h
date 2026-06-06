#import <Foundation/Foundation.h>

@class LAActivator;

static NSString *const LAActivatorIPCServerName = @"libactivator.springboard";

static NSString *const LAActivatorIPCMessageAvailableEventNames = @"libactivator.request.available-event-names";
static NSString *const LAActivatorIPCMessageHasEvent = @"libactivator.request.has-event";
static NSString *const LAActivatorIPCMessageAvailableListenerNames = @"libactivator.request.available-listener-names";
static NSString *const LAActivatorIPCMessageHasListener = @"libactivator.request.has-listener";
static NSString *const LAActivatorIPCMessageAssignedListenerNames = @"libactivator.request.assigned-listener-names";
static NSString *const LAActivatorIPCMessageEventsAssignedToListener = @"libactivator.request.events-assigned-to-listener";
static NSString *const LAActivatorIPCMessageAssignEvent = @"libactivator.request.assign-event";
static NSString *const LAActivatorIPCMessageUnassignEvent = @"libactivator.request.unassign-event";
static NSString *const LAActivatorIPCMessageApplicationIsBlacklisted = @"libactivator.request.application-is-blacklisted";
static NSString *const LAActivatorIPCMessageSetApplicationBlacklisted = @"libactivator.request.set-application-blacklisted";
static NSString *const LAActivatorIPCMessageAvailableProfileNames = @"libactivator.request.available-profile-names";
static NSString *const LAActivatorIPCMessageCurrentProfileName = @"libactivator.request.current-profile-name";
static NSString *const LAActivatorIPCMessageSetCurrentProfileName = @"libactivator.request.set-current-profile-name";

static NSString *const LAActivatorIPCMessageEventIsHidden = @"libactivator.request.event-is-hidden";
static NSString *const LAActivatorIPCMessageEventRequiresAssignment = @"libactivator.request.event-requires-assignment";
static NSString *const LAActivatorIPCMessageCompatibleModesForEvent =
    @"libactivator.request.compatible-modes-for-event";
static NSString *const LAActivatorIPCMessageEventIsCompatibleWithMode =
    @"libactivator.request.event-is-compatible-with-mode";
static NSString *const LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend =
    @"libactivator.request.event-supports-unlocking-device-to-send";
static NSString *const LAActivatorIPCMessageEventSupportsRemoval =
    @"libactivator.request.event-supports-removal";
static NSString *const LAActivatorIPCMessageEventSupportsConfiguration =
    @"libactivator.request.event-supports-configuration";

static NSString *const LAActivatorIPCMessageListenerInfoDictionaryValue =
    @"libactivator.request.listener-info-dictionary-value";
static NSString *const LAActivatorIPCMessageListenerRequiresAssignment =
    @"libactivator.request.listener-requires-assignment";
static NSString *const LAActivatorIPCMessageCompatibleModesForListener =
    @"libactivator.request.compatible-modes-for-listener";
static NSString *const LAActivatorIPCMessageListenerIsCompatibleWithMode =
    @"libactivator.request.listener-is-compatible-with-mode";
static NSString *const LAActivatorIPCMessageListenerIsCompatibleWithEvent =
    @"libactivator.request.listener-is-compatible-with-event";
static NSString *const LAActivatorIPCMessageListenerNeedsPoweredDisplay =
    @"libactivator.request.listener-needs-powered-display";
static NSString *const LAActivatorIPCMessageExclusiveAssignmentGroupsForListener =
    @"libactivator.request.exclusive-assignment-groups-for-listener";
static NSString *const LAActivatorIPCMessageListenerNamesAreMutuallyCompatible =
    @"libactivator.request.listener-names-are-mutually-compatible";
static NSString *const LAActivatorIPCMessageListenerSupportsRemoval =
    @"libactivator.request.listener-supports-removal";
static NSString *const LAActivatorIPCMessageListenerSupportsConfiguration =
    @"libactivator.request.listener-supports-configuration";

static NSString *const LAActivatorIPCMessageLocalizedTitleForEventName =
    @"libactivator.request.localized-title-for-event-name";
static NSString *const LAActivatorIPCMessageLocalizedTitleForListenerName =
    @"libactivator.request.localized-title-for-listener-name";
static NSString *const LAActivatorIPCMessageLocalizedTitleForListenerNames =
    @"libactivator.request.localized-title-for-listener-names";
static NSString *const LAActivatorIPCMessageLocalizedGroupForEventName =
    @"libactivator.request.localized-group-for-event-name";
static NSString *const LAActivatorIPCMessageLocalizedGroupForListenerName =
    @"libactivator.request.localized-group-for-listener-name";
static NSString *const LAActivatorIPCMessageLocalizedDescriptionForEventName =
    @"libactivator.request.localized-description-for-event-name";
static NSString *const LAActivatorIPCMessageLocalizedDescriptionForListenerName =
    @"libactivator.request.localized-description-for-listener-name";

static NSString *const LAActivatorIPCKeyOK = @"OK";
static NSString *const LAActivatorIPCKeyValue = @"Value";
static NSString *const LAActivatorIPCKeyEventName = @"EventName";
static NSString *const LAActivatorIPCKeyEventMode = @"EventMode";
static NSString *const LAActivatorIPCKeyListenerName = @"ListenerName";
static NSString *const LAActivatorIPCKeyListenerNames = @"ListenerNames";
static NSString *const LAActivatorIPCKeyDisplayIdentifier = @"DisplayIdentifier";
static NSString *const LAActivatorIPCKeyBlacklisted = @"Blacklisted";
static NSString *const LAActivatorIPCKeyProfileName = @"ProfileName";
static NSString *const LAActivatorIPCKeyInfoDictionaryKey = @"InfoDictionaryKey";

__attribute__((visibility("hidden")))
@interface LAActivatorIPCClient : NSObject
- (NSArray *)arrayValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSString *)stringValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (id)propertyListValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (BOOL)boolValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo defaultValue:(BOOL)defaultValue;
- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
@end

__attribute__((visibility("hidden")))
@interface LAActivatorIPCServer : NSObject
- (instancetype)initWithActivator:(LAActivator *)activator;
- (void)start;
@end
