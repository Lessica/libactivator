#import <Foundation/Foundation.h>

@class LAActivator;

#define LA_IPC_EXTERN extern __attribute__((visibility("hidden")))

LA_IPC_EXTERN NSString *const LAActivatorIPCServerName;

LA_IPC_EXTERN NSString *const LAActivatorIPCMessageAvailableEventNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageHasEvent;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageAvailableListenerNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageHasListener;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageAssignedListenerNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventsAssignedToListener;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageAssignEvent;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageUnassignEvent;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageApplicationIsBlacklisted;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageSetApplicationBlacklisted;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageAvailableProfileNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageCurrentProfileName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageSetCurrentProfileName;

LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventIsHidden;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventRequiresAssignment;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageCompatibleModesForEvent;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventIsCompatibleWithMode;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventSupportsRemoval;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageEventSupportsConfiguration;

LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerInfoDictionaryValue;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerRequiresAssignment;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageCompatibleModesForListener;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerIsCompatibleWithMode;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerIsCompatibleWithEvent;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerNeedsPoweredDisplay;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageExclusiveAssignmentGroupsForListener;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerNamesAreMutuallyCompatible;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerSupportsRemoval;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageListenerSupportsConfiguration;

LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedTitleForEventName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedTitleForListenerName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedTitleForListenerNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedGroupForEventName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedGroupForListenerName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedDescriptionForEventName;
LA_IPC_EXTERN NSString *const LAActivatorIPCMessageLocalizedDescriptionForListenerName;

LA_IPC_EXTERN NSString *const LAActivatorIPCKeyOK;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyValue;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyEventName;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyEventMode;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyListenerName;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyListenerNames;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyDisplayIdentifier;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyBlacklisted;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyProfileName;
LA_IPC_EXTERN NSString *const LAActivatorIPCKeyInfoDictionaryKey;

#undef LA_IPC_EXTERN

__attribute__((visibility("hidden")))
@interface LAActivatorIPCClient : NSObject
- (NSArray *)arrayValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSString *)stringValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (id)propertyListValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (BOOL)boolValueForMessageName:(NSString *)messageName
                       userInfo:(NSDictionary *)userInfo
                   defaultValue:(BOOL)defaultValue;
- (NSArray *)eventsValueForMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
@end

__attribute__((visibility("hidden")))
@interface LAActivatorIPCServer : NSObject
- (instancetype)initWithActivator:(LAActivator *)activator;
- (void)start;
@end
