//
//  LAIPC.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;
@class LAEvent;

#if LIBACTIVATOR_TEST_SUPPORT
#define LA_IPC_EXTERN extern __attribute__((visibility("default")))
#else
#define LA_IPC_EXTERN extern __attribute__((visibility("hidden")))
#endif

LA_IPC_EXTERN NSString *const LAIPCServerName;

#pragma mark - Registry Messages

LA_IPC_EXTERN NSString *const LAIPCMessageAvailableEventNames;
LA_IPC_EXTERN NSString *const LAIPCMessageHasEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageAvailableListenerNames;
LA_IPC_EXTERN NSString *const LAIPCMessageHasListener;
LA_IPC_EXTERN NSString *const LAIPCMessageHasSeenListener;
LA_IPC_EXTERN NSString *const LAIPCMessageAssignedListenerNames;
LA_IPC_EXTERN NSString *const LAIPCMessageEventsAssignedToListener;
LA_IPC_EXTERN NSString *const LAIPCMessageAssignEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageAddListenerAssignment;
LA_IPC_EXTERN NSString *const LAIPCMessageRemoveListenerAssignment;
LA_IPC_EXTERN NSString *const LAIPCMessageUnassignEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageApplicationIsBlacklisted;
LA_IPC_EXTERN NSString *const LAIPCMessageSetApplicationBlacklisted;
LA_IPC_EXTERN NSString *const LAIPCMessageAvailableProfileNames;
LA_IPC_EXTERN NSString *const LAIPCMessageCurrentProfileName;
LA_IPC_EXTERN NSString *const LAIPCMessageSetCurrentProfileName;
LA_IPC_EXTERN NSString *const LAIPCMessagePreferenceValue;
LA_IPC_EXTERN NSString *const LAIPCMessageSetPreferenceValue;

#pragma mark - Runtime Messages

LA_IPC_EXTERN NSString *const LAIPCMessageCurrentEventMode;
LA_IPC_EXTERN NSString *const LAIPCMessageCurrentEventModeUnderneathLockScreen;
LA_IPC_EXTERN NSString *const LAIPCMessageSupportsUnlockingDeviceToSendEvents;
LA_IPC_EXTERN NSString *const LAIPCMessageCurrentApplicationDisplayIdentifier;

#pragma mark - Application Accessibility Messages

LA_IPC_EXTERN NSString *const LAIPCMessageApplicationAccessibilityEnabled;
LA_IPC_EXTERN NSString *const LAIPCMessageSetApplicationAccessibilityEnabled;

#pragma mark - Event Metadata Messages

LA_IPC_EXTERN NSString *const LAIPCMessageEventIsHidden;
LA_IPC_EXTERN NSString *const LAIPCMessageEventRequiresAssignment;
LA_IPC_EXTERN NSString *const LAIPCMessageCompatibleModesForEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageEventIsCompatibleWithMode;
LA_IPC_EXTERN NSString *const LAIPCMessageEventSupportsUnlockingDeviceToSend;
LA_IPC_EXTERN NSString *const LAIPCMessageAssignmentWarningForEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageEventIsUnprotected;
LA_IPC_EXTERN NSString *const LAIPCMessageEventSupportsRemoval;
LA_IPC_EXTERN NSString *const LAIPCMessageEventSupportsConfiguration;

#pragma mark - Listener Metadata Messages

LA_IPC_EXTERN NSString *const LAIPCMessageListenerInfoDictionaryValue;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerRequiresAssignment;
LA_IPC_EXTERN NSString *const LAIPCMessageCompatibleModesForListener;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerIsCompatibleWithMode;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerIsCompatibleWithEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerNeedsPoweredDisplay;
LA_IPC_EXTERN NSString *const LAIPCMessageExclusiveAssignmentGroupsForListener;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerNamesAreMutuallyCompatible;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerSupportsRemoval;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerSupportsConfiguration;

#pragma mark - Localization Messages

LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedTitleForEventName;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedTitleForListenerName;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedTitleForListenerNames;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedGroupForEventName;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedGroupForListenerName;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedDescriptionForEventName;
LA_IPC_EXTERN NSString *const LAIPCMessageLocalizedDescriptionForListenerName;

#pragma mark - Dispatch Messages

LA_IPC_EXTERN NSString *const LAIPCMessageDispatchAssignedEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageDispatchEventToListeners;
LA_IPC_EXTERN NSString *const LAIPCMessageDispatchAssignedAbortEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageDispatchAbortEventToListeners;
LA_IPC_EXTERN NSString *const LAIPCMessageDispatchPreviewEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageDispatchDeactivateEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageRemoteListenerReceiveEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageRemoteListenerAbortEvent;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerSmallIconData;
LA_IPC_EXTERN NSString *const LAIPCMessageRequestListenerRemoval;
LA_IPC_EXTERN NSString *const LAIPCMessageRemoveEvent;

#if LIBACTIVATOR_TEST_SUPPORT
LA_IPC_EXTERN NSString *const LAIPCMessageTesting;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandPing;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandCleanup;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandRun;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandRunRuntimeInput;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandRunDeviceRuntime;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandRuntimeState;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandPrepareUserInfoProbe;
LA_IPC_EXTERN NSString *const LAIPCTestingCommandUserInfoProbeResult;
#endif

#pragma mark - UserInfo Keys

LA_IPC_EXTERN NSString *const LAIPCKeyOK;
LA_IPC_EXTERN NSString *const LAIPCKeyValue;
LA_IPC_EXTERN NSString *const LAIPCKeyEventName;
LA_IPC_EXTERN NSString *const LAIPCKeyEventMode;
LA_IPC_EXTERN NSString *const LAIPCKeyEventHandled;
LA_IPC_EXTERN NSString *const LAIPCKeyEventUserInfo;
LA_IPC_EXTERN NSString *const LAIPCKeyListenerName;
LA_IPC_EXTERN NSString *const LAIPCKeyListenerNames;
LA_IPC_EXTERN NSString *const LAIPCKeyDisplayIdentifier;
LA_IPC_EXTERN NSString *const LAIPCKeyBlacklisted;
LA_IPC_EXTERN NSString *const LAIPCKeyProfileName;
LA_IPC_EXTERN NSString *const LAIPCKeyPreferenceKey;
LA_IPC_EXTERN NSString *const LAIPCKeyPreferenceValue;
LA_IPC_EXTERN NSString *const LAIPCKeyInfoDictionaryKey;
LA_IPC_EXTERN NSString *const LAIPCKeyScale;
LA_IPC_EXTERN NSString *const LAIPCKeyApplicationAccessibilityEnabled;

#if LIBACTIVATOR_TEST_SUPPORT
LA_IPC_EXTERN NSString *const LAIPCKeyTestingCommand;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingSuites;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingFailures;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingSkipped;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingCaseCount;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingPassCount;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingFailureCount;
LA_IPC_EXTERN NSString *const LAIPCKeyTestingSkipCount;
#endif

#if LIBACTIVATOR_TEST_SUPPORT
LA_IPC_EXTERN NSString *const LAIPCMessageEventDispatchCounts;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerReceiveCounts;
LA_IPC_EXTERN NSString *const LAIPCMessageEventAbortCounts;
LA_IPC_EXTERN NSString *const LAIPCMessageListenerAbortCounts;
LA_IPC_EXTERN NSString *const LAIPCMessageResetDispatchCounts;
#endif

#undef LA_IPC_EXTERN

__attribute__((visibility("hidden")))
@interface LAIPCClient : NSObject

#pragma mark - Requests

- (nullable NSDictionary<NSString *, id> *)replyForMessageName:(NSString *)messageName
                                                      userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (NSArray<id> *)arrayValueForMessageName:(NSString *)messageName
                                 userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (nullable NSString *)stringValueForMessageName:(NSString *)messageName
                                        userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (nullable id)propertyListValueForMessageName:(NSString *)messageName
                                      userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (BOOL)boolValueForMessageName:(NSString *)messageName
                       userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
                   defaultValue:(BOOL)defaultValue;
- (NSArray<LAEvent *> *)eventsValueForMessageName:(NSString *)messageName
                                         userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;
- (BOOL)sendEventMessageName:(NSString *)messageName
                    userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
                       event:(LAEvent *)event;
- (BOOL)sendMessageName:(NSString *)messageName userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;

@end

__attribute__((visibility("hidden")))
@interface LAIPCServer : NSObject
- (instancetype)initWithActivator:(LAActivator *)activator;
- (void)start;
@end

NS_ASSUME_NONNULL_END
