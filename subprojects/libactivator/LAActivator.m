//
//  LAActivator.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <HBLog.h>
#import <dispatch/dispatch.h>
#import <notify.h>

#import "LAActivator+Private.h"
#import "LADefaultEventDataSource.h"
#import "LAIPC.h"
#import "LALegacyPreferenceBridge.h"
#import "LAListenerMetadataCache.h"
#import "LAPersistence.h"
#import "LARemoteListener.h"
#import "LAResourceManager.h"
#import "LARuntimeBackend.h"
#import "LARuntimeStateProvider.h"
#import "LAScreenWakeCoordinator.h"
#import "LATouchActivityTracker.h"

#pragma mark - Class Extension

@interface LAActivator ()
@property(nonatomic, strong) LARuntimeBackend *backend;
@property(nonatomic, strong) LAIPCClient *ipcClient;
@property(nonatomic, strong) LAIPCServer *ipcServer;
@property(nonatomic, strong) LARuntimeStateProvider *runtimeStateProvider;
@property(nonatomic, strong) LATouchActivityTracker *touchActivityTracker;
@property(nonatomic, strong) LAListenerMetadataCache *listenerMetadataCache;
@property(nonatomic, strong) LALegacyPreferenceBridge *legacyPreferenceBridge;
@property(nonatomic, strong) LAScreenWakeCoordinator *screenWakeCoordinator;
@property(nonatomic, strong) LADefaultEventDataSource *defaultEventDataSource;
@property(nonatomic, strong) LARemoteListener *remoteListener;
- (void)la_handleSystemNotificationNamed:(NSString *)darwinName;
@end

static NSString *const LAActivatorDarwinAvailableListenersChangedNotification =
    @"libactivator.notification.available-listeners-changed";
static NSString *const LAActivatorDarwinAvailableEventsChangedNotification =
    @"libactivator.notification.available-events-changed";
static NSString *const LAActivatorDarwinAssignmentsChangedNotification =
    @"libactivator.notification.assignments-changed";
static NSString *const LAActivatorDarwinEventModeChangedNotification = @"libactivator.notification.event-mode-changed";

static void LAActivatorSystemNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                                  const void *object, CFDictionaryRef userInfo) {
    LAActivator *activator = (__bridge LAActivator *)observer;
    [activator la_handleSystemNotificationNamed:(__bridge NSString *)name];
}

@implementation LAActivator

#pragma mark - Lifecycle

LAActivator *LASharedActivator;

+ (void)load {
    [self sharedInstance];
}

+ (LAActivator *)sharedInstance {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        LASharedActivator = [[self alloc] initPrivate];
    });
    return LASharedActivator;
}

- (instancetype)init {
    return [[self class] sharedInstance];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _listenerMetadataCache = [[LAListenerMetadataCache alloc] init];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(la_didReceiveMemoryWarning:)
                                                   name:UIApplicationDidReceiveMemoryWarningNotification
                                                 object:nil];
        if (self.runningInsideSpringBoard) {
            _runtimeStateProvider = [[LARuntimeStateProvider alloc] init];
            _backend = [[LARuntimeBackend alloc] initWithPersistence:[self defaultPersistence]];
            _legacyPreferenceBridge = [[LALegacyPreferenceBridge alloc] initWithBackend:_backend];
            _touchActivityTracker = [[LATouchActivityTracker alloc] init];
            _screenWakeCoordinator = [[LAScreenWakeCoordinator alloc] init];
            _defaultEventDataSource = [[LADefaultEventDataSource alloc] init];
            __weak typeof(self) weakSelf = self;
            [_runtimeStateProvider setEventModeChangeHandler:^(NSString *eventMode) {
                [weakSelf la_notifyEventModeChanged:eventMode];
            }];
            [_screenWakeCoordinator startObservingScreenStateWithActivator:self];
            [_defaultEventDataSource registerAvailableEventsWithActivator:self];
        } else {
            _ipcClient = [[LAIPCClient alloc] init];
            _remoteListener = [[LARemoteListener alloc] init];
            [self la_registerSystemNotificationBridgeIfNeeded];
        }
    }
    return self;
}

- (LAPersistence *)defaultPersistence {
    LAPersistence *persistence;
#if LA_TESTING
    persistence = [LAPersistence testingPersistence];
#else
    persistence = [LAPersistence defaultPersistence];
#endif
    return persistence;
}

#pragma mark - Legacy Preferences

- (id)_getObjectForPreference:(NSString *)preference {
    if (preference.length == 0) {
        return nil;
    }
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyPreferenceKey : preference ?: @""};
        return [self.ipcClient propertyListValueForMessageName:LAIPCMessagePreferenceValue userInfo:userInfo];
    }
    return [self.legacyPreferenceBridge objectForPreferenceKey:preference];
}

- (void)_setObject:(id)value forPreference:(NSString *)preference {
    if (preference.length == 0) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [@{LAIPCKeyPreferenceKey : preference ?: @""} mutableCopy];
        id propertyListValue = [self la_ipcPropertyListValue:value];
        if (propertyListValue) {
            userInfo[LAIPCKeyPreferenceValue] = propertyListValue;
        }
        [self.ipcClient sendMessageName:LAIPCMessageSetPreferenceValue userInfo:userInfo];
        return;
    }
    [self.legacyPreferenceBridge setObject:value forPreferenceKey:preference];
}

#pragma mark - Runtime State

- (LAActivatorVersion)version {
    return LAActivatorVersion_2_0;
}

- (BOOL)isRunningInsideSpringBoard {
    NSString *procName = [[NSProcessInfo processInfo] processName];
    if (![procName isEqualToString:@"SpringBoard"]) {
        return NO; // Fast path for the common case
    }
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleId isEqualToString:@"com.apple.springboard"];
}

- (BOOL)isDangerousToSendEvents {
    return NO; // Deprecated
}

- (void)startIPCServerIfNeeded {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    if (!self.ipcServer) {
        self.ipcServer = [[LAIPCServer alloc] initWithActivator:self];
    }
    [self.ipcServer start];
}

- (void)la_registerSystemNotificationBridgeIfNeeded {
    NSArray *notificationNames = @[
        LAActivatorDarwinAvailableListenersChangedNotification,
        LAActivatorDarwinAvailableEventsChangedNotification,
        LAActivatorDarwinAssignmentsChangedNotification,
        LAActivatorDarwinEventModeChangedNotification,
    ];
    for (NSString *notificationName in notificationNames) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self,
                                        LAActivatorSystemNotificationCallback, (__bridge CFStringRef)notificationName,
                                        NULL, CFNotificationSuspensionBehaviorCoalesce);
    }
}

- (NSString *)la_publicNotificationNameForDarwinName:(NSString *)darwinName {
    if ([darwinName isEqualToString:LAActivatorDarwinAvailableListenersChangedNotification]) {
        return LAActivatorAvailableListenersChangedNotification;
    }
    if ([darwinName isEqualToString:LAActivatorDarwinAvailableEventsChangedNotification]) {
        return LAActivatorAvailableEventsChangedNotification;
    }
    if ([darwinName isEqualToString:LAActivatorDarwinAssignmentsChangedNotification]) {
        return LAActivatorAssignmentsChangedNotification;
    }
    if ([darwinName isEqualToString:LAActivatorDarwinEventModeChangedNotification]) {
        return LAActivatorEventModeChangedNotification;
    }
    return nil;
}

- (NSString *)la_darwinNotificationNameForPublicName:(NSString *)publicName {
    if ([publicName isEqualToString:LAActivatorAvailableListenersChangedNotification]) {
        return LAActivatorDarwinAvailableListenersChangedNotification;
    }
    if ([publicName isEqualToString:LAActivatorAvailableEventsChangedNotification]) {
        return LAActivatorDarwinAvailableEventsChangedNotification;
    }
    if ([publicName isEqualToString:LAActivatorAssignmentsChangedNotification]) {
        return LAActivatorDarwinAssignmentsChangedNotification;
    }
    if ([publicName isEqualToString:LAActivatorEventModeChangedNotification]) {
        return LAActivatorDarwinEventModeChangedNotification;
    }
    return nil;
}

- (void)la_handleSystemNotificationNamed:(NSString *)darwinName {
    NSString *notificationName = [self la_publicNotificationNameForDarwinName:darwinName];
    if (notificationName.length == 0) {
        return;
    }
    if ([notificationName isEqualToString:LAActivatorAvailableListenersChangedNotification]) {
        [self la_clearListenerMetadataCaches];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:notificationName object:self];
}

- (void)la_postSystemNotificationName:(NSString *)notificationName {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    NSString *darwinName = [self la_darwinNotificationNameForPublicName:notificationName];
    if (darwinName.length == 0) {
        return;
    }
    if ([notificationName isEqualToString:LAActivatorAvailableListenersChangedNotification]) {
        [self la_clearListenerMetadataCaches];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:notificationName object:self];
    notify_post(darwinName.UTF8String);
}

- (void)la_noteHomeScreenVisible:(BOOL)visible {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteHomeScreenVisible:visible];
}

- (void)la_noteHomeScreenVisible:(BOOL)visible source:(NSString *)source {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteHomeScreenVisible:visible source:source];
}

- (void)la_noteSpringBoardInterfaceVisible:(BOOL)visible source:(NSString *)source {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteSpringBoardInterfaceVisible:visible source:source];
}

- (void)la_noteLockScreenVisible:(BOOL)visible {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteLockScreenVisible:visible];
}

- (void)la_noteLockScreenVisible:(BOOL)visible source:(NSString *)source {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteLockScreenVisible:visible source:source];
}

- (void)la_noteScreenBlanked:(BOOL)blanked {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteScreenBlanked:blanked];
}

- (void)la_noteRuntimeStateMayHaveChanged {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteRuntimeStateMayHaveChanged];
}

- (void)la_noteSystemTouchEvent:(UIEvent *)event {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.touchActivityTracker noteTouchEvent:event];
}

- (BOOL)la_screenIsOn {
    if (!self.runningInsideSpringBoard) {
        return YES;
    }
    return self.runtimeStateProvider.screenIsOn;
}

- (BOOL)la_wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion {
    if (!self.runningInsideSpringBoard) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        return completion != nil;
    }
    return [self.screenWakeCoordinator wakeScreenForReason:reason completion:completion];
}

#if LA_TESTING
- (NSDictionary *)la_runtimeStateDebugDictionary {
    if (!self.runningInsideSpringBoard) {
        return @{};
    }
    return [self.runtimeStateProvider testingDebugDictionary] ?: @{};
}
#endif

#pragma mark - Event Delivery

- (id<LAListener>)listenerForEvent:(LAEvent *)event {
    NSString *listenerName = [self assignedListenerNameForEvent:event];
    return [self listenerForName:listenerName];
}

- (void)sendEventToListener:(LAEvent *)event {
    if (!event) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAIPCMessageDispatchAssignedEvent
                                    userInfo:[self la_ipcUserInfoForEvent:event]
                                       event:event];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendEventToListener:event];
        });
        return;
    }
    [self la_sendEvent:event toListenerNames:[self assignedListenerNamesForEvent:event] allowDeferral:YES];
}

- (void)sendEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
    [self sendEvent:event toListenersWithNames:listenerName.length > 0 ? @[ listenerName ] : @[]];
}

- (void)sendEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    if (!event) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAIPCKeyListenerNames] = [self la_ipcUniqueStringArrayPreservingOrder:listenerNames];
        [self.ipcClient sendEventMessageName:LAIPCMessageDispatchEventToListeners userInfo:userInfo event:event];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendEvent:event toListenersWithNames:listenerNames];
        });
        return;
    }
    [self la_sendEvent:event toListenerNames:listenerNames allowDeferral:YES];
}

- (void)sendAbortToListener:(LAEvent *)event {
    if (!event) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAIPCMessageDispatchAssignedAbortEvent
                                    userInfo:[self la_ipcUserInfoForEvent:event]
                                       event:event];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendAbortToListener:event];
        });
        return;
    }
    [self la_sendAbortEvent:event toListenerNames:[self assignedListenerNamesForEvent:event]];
}

- (void)sendAbortEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
    [self sendAbortEvent:event toListenersWithNames:listenerName.length > 0 ? @[ listenerName ] : @[]];
}

- (void)sendAbortEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    if (!event) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAIPCKeyListenerNames] = [self la_ipcUniqueStringArrayPreservingOrder:listenerNames];
        [self.ipcClient sendEventMessageName:LAIPCMessageDispatchAbortEventToListeners userInfo:userInfo event:event];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendAbortEvent:event toListenersWithNames:listenerNames];
        });
        return;
    }
    [self la_sendAbortEvent:event toListenerNames:listenerNames];
}

- (void)sendPreviewEventToListenerWithName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        [self.ipcClient sendMessageName:LAIPCMessageDispatchPreviewEvent userInfo:userInfo];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendPreviewEventToListenerWithName:listenerName];
        });
        return;
    }
    if (listenerName.length == 0) {
        return;
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if ([listener respondsToSelector:@selector(activator:receivePreviewEventForListenerName:)]) {
        [listener activator:self receivePreviewEventForListenerName:listenerName];
    }
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event {
    if (!event) {
        return;
    }
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAIPCMessageDispatchDeactivateEvent
                                    userInfo:[self la_ipcUserInfoForEvent:event]
                                       event:event];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self sendDeactivateEventToListeners:event];
        });
        return;
    }
    BOOL handled = event.handled;
    event.handled = NO;
    for (id<LAListener> listener in [self.backend registeredListeners]) {
        if ([listener respondsToSelector:@selector(activator:receiveDeactivateEvent:)]) {
            [listener activator:self receiveDeactivateEvent:event];
            if (event.handled) {
                handled = YES;
                event.handled = NO;
            }
        }
    }
    event.handled = handled;
}

- (NSArray *)la_dispatchableListenerNames:(NSArray *)listenerNames forEvent:(LAEvent *)event {
    if (!self.runningInsideSpringBoard || event.name.length == 0) {
        return @[];
    }

    NSString *eventMode = event.mode ?: self.currentEventMode;
    if (eventMode.length == 0) {
        return @[];
    }

    NSMutableArray *dispatchableNames = [NSMutableArray array];
    NSMutableSet *seenNames = [NSMutableSet set];
    for (id value in listenerNames) {
        if (![value isKindOfClass:NSString.class] || [value length] == 0 || [seenNames containsObject:value]) {
            continue;
        }
        NSString *listenerName = value;
        [seenNames addObject:listenerName];
        if (![self listenerForName:listenerName]) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithMode:eventMode]) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithEventName:event.name]) {
            continue;
        }
        if ([self listenerWithNameNeedsPoweredDisplay:listenerName] && !self.runtimeStateProvider.screenIsOn) {
            continue;
        }
        [dispatchableNames addObject:listenerName];
    }
    return [dispatchableNames copy];
}

- (void)la_sendEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames allowDeferral:(BOOL)allowDeferral {
    if (!self.runningInsideSpringBoard || !event) {
        return;
    }

    NSString *eventMode = event.mode ?: self.currentEventMode;
    if ([eventMode isEqualToString:LAEventModeLockScreen] && [self la_sendUnlockingEvent:event
                                                                         toListenerNames:listenerNames
                                                                               eventMode:eventMode]) {
        return;
    }

    NSString *displayIdentifier = self.displayIdentifierForCurrentApplication;
    if (displayIdentifier.length > 0 && [self applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier]) {
        return;
    }

    BOOL touchActive = allowDeferral && self.touchActivityTracker.touchActive;
    for (NSString *listenerName in [self la_dispatchableListenerNames:listenerNames forEvent:event]) {
        id<LAListener> listener = [self listenerForName:listenerName];
        if (touchActive && [self la_listenerWithNameRequiresNoTouchEvents:listenerName]) {
            LAEvent *deferredEvent = [LAEvent eventWithName:event.name mode:event.mode];
            deferredEvent.userInfo = event.userInfo;
            BOOL wasHandled = event.handled;
            event.handled = YES;
            if (!wasHandled) {
                [self la_notifyListenersThatListener:listener handledEvent:event];
            }
            __weak typeof(self) weakSelf = self;
            [self.touchActivityTracker performWhenTouchesEnd:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                deferredEvent.handled = NO;
                [strongSelf la_sendEvent:deferredEvent directlyToListenerWithName:listenerName abort:NO];
            }];
            continue;
        }

        BOOL wasHandled = event.handled;
        if ([listener respondsToSelector:@selector(activator:receiveEvent:forListenerName:)]) {
            [listener activator:self receiveEvent:event forListenerName:listenerName];
        } else if ([listener respondsToSelector:@selector(activator:receiveEvent:)]) {
            [listener activator:self receiveEvent:event];
        }
        if (!wasHandled && event.handled) {
            [self la_notifyListenersThatListener:listener handledEvent:event];
        }
    }
}

- (BOOL)la_sendUnlockingEvent:(LAEvent *)event
              toListenerNames:(NSArray *)listenerNames
                    eventMode:(NSString *)eventMode {
    if (![eventMode isEqualToString:LAEventModeLockScreen] || !self.supportsUnlockingDeviceToSendEvents ||
        ![self eventWithNameSupportsUnlockingDeviceToSend:event.name]) {
        return NO;
    }

    NSString *underneathMode = self.currentEventModeUnderneathLockScreen;
    if (underneathMode.length == 0 || [underneathMode isEqualToString:LAEventModeLockScreen]) {
        return NO;
    }

    BOOL unlockingEventWasHandled = NO;
    NSMutableSet *seenNames = [NSMutableSet set];
    for (id value in listenerNames) {
        if (![value isKindOfClass:NSString.class] || [value length] == 0 || [seenNames containsObject:value]) {
            continue;
        }
        NSString *listenerName = value;
        [seenNames addObject:listenerName];

        id<LAListener> listener = [self listenerForName:listenerName];
        if (!listener ||
            ![listener respondsToSelector:@selector(activator:receiveUnlockingDeviceEvent:forListenerName:)]) {
            continue;
        }
        if ([self listenerWithName:listenerName isCompatibleWithMode:eventMode]) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithMode:underneathMode]) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithEventName:event.name]) {
            continue;
        }

        BOOL wasHandled = event.handled;
        BOOL handled = [listener activator:self receiveUnlockingDeviceEvent:event forListenerName:listenerName];
        if (handled) {
            event.handled = YES;
            unlockingEventWasHandled = YES;
        }
        if (!wasHandled && event.handled) {
            unlockingEventWasHandled = YES;
            [self la_notifyListenersThatListener:listener handledEvent:event];
        }
    }
    return unlockingEventWasHandled;
}

- (BOOL)la_listenerWithNameRequiresNoTouchEvents:(NSString *)listenerName {
    return [[self infoDictionaryValueOfKey:@"requires-no-touch-events" forListenerWithName:listenerName] boolValue];
}

- (void)la_sendAbortEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames {
    if (!self.runningInsideSpringBoard || !event) {
        return;
    }

    for (NSString *listenerName in [self la_dispatchableListenerNames:listenerNames forEvent:event]) {
        id<LAListener> listener = [self listenerForName:listenerName];
        if ([listener respondsToSelector:@selector(activator:abortEvent:forListenerName:)]) {
            [listener activator:self abortEvent:event forListenerName:listenerName];
        } else if ([listener respondsToSelector:@selector(activator:abortEvent:)]) {
            [listener activator:self abortEvent:event];
        }
    }
}

- (void)la_sendEvent:(LAEvent *)event directlyToListenerWithName:(NSString *)listenerName abort:(BOOL)abort {
    if (!self.runningInsideSpringBoard || !event || listenerName.length == 0) {
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self la_sendEvent:event directlyToListenerWithName:listenerName abort:abort];
        });
        return;
    }

    id<LAListener> listener = [self listenerForName:listenerName];
    if (!listener) {
        return;
    }
    if (abort) {
        if ([listener respondsToSelector:@selector(activator:abortEvent:forListenerName:)]) {
            [listener activator:self abortEvent:event forListenerName:listenerName];
        } else if ([listener respondsToSelector:@selector(activator:abortEvent:)]) {
            [listener activator:self abortEvent:event];
        }
        return;
    }
    if ([listener respondsToSelector:@selector(activator:receiveEvent:forListenerName:)]) {
        [listener activator:self receiveEvent:event forListenerName:listenerName];
    } else if ([listener respondsToSelector:@selector(activator:receiveEvent:)]) {
        [listener activator:self receiveEvent:event];
    }
}

- (void)la_notifyEventModeChanged:(NSString *)eventMode {
    if (!self.runningInsideSpringBoard || eventMode.length == 0) {
        return;
    }

    for (id<LAListener> listener in [self.backend registeredListeners]) {
        if ([listener respondsToSelector:@selector(activator:didChangeToEventMode:)]) {
            [listener activator:self didChangeToEventMode:eventMode];
        }
    }
    [self la_postSystemNotificationName:LAActivatorEventModeChangedNotification];
}

- (void)la_notifyListenersThatListener:(id<LAListener>)handlingListener handledEvent:(LAEvent *)event {
    for (id<LAListener> listener in [self.backend registeredListeners]) {
        if (listener == handlingListener) {
            continue;
        }
        if ([listener respondsToSelector:@selector(activator:otherListenerDidHandleEvent:)]) {
            [listener activator:self otherListenerDidHandleEvent:event];
        }
    }
}

- (void)la_rejectSpringBoardOnlySelector:(SEL)selector {
    NSString *selectorName = NSStringFromSelector(selector);
    NSString *culprit = [self la_invalidSpringBoardOperationCulpritName];

    HBLogError(@"Invalid SpringBoard operation: %@ called -[LAActivator %@] from outside SpringBoard. "
                "This call was rejected and no client-local runtime state was created. Contact %@'s developer.",
               culprit, selectorName, culprit);
}

- (NSString *)la_invalidSpringBoardOperationCulpritName {
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSString *culprit = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (culprit.length == 0) {
        culprit = [mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
    }
    if (culprit.length == 0) {
        culprit = mainBundle.bundleIdentifier;
    }
    if (culprit.length == 0) {
        culprit = NSProcessInfo.processInfo.processName;
    }
    return culprit.length > 0 ? culprit : @"This process";
}

#pragma mark - IPC Serialization

- (id)la_ipcPropertyListValue:(id)value {
    if (!value) {
        return nil;
    }

    if ([NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        return value;
    }

    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        for (id key in value) {
            if (![key isKindOfClass:NSString.class]) {
                continue;
            }
            id sanitizedValue = [self la_ipcPropertyListValue:value[key]];
            if (sanitizedValue) {
                dictionary[key] = sanitizedValue;
            }
        }
        return [dictionary copy];
    }

    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:[value count]];
        for (id item in value) {
            id sanitizedItem = [self la_ipcPropertyListValue:item];
            if (sanitizedItem) {
                [array addObject:sanitizedItem];
            }
        }
        return [array copy];
    }

    return nil;
}

- (NSDictionary *)la_ipcUserInfoForEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAIPCKeyEventMode] = event.mode;
    }
    userInfo[LAIPCKeyEventHandled] = @(event.handled);

    NSDictionary *eventUserInfo = [self la_ipcPropertyListValue:event.userInfo];
    if (eventUserInfo) {
        userInfo[LAIPCKeyEventUserInfo] = eventUserInfo;
    }
    return [userInfo copy];
}

- (NSArray *)la_ipcUniqueStringArrayPreservingOrder:(NSArray *)array {
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    NSMutableSet *seenStrings = [NSMutableSet set];
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![seenStrings containsObject:value]) {
            [seenStrings addObject:value];
            [strings addObject:value];
        }
    }
    return [strings copy];
}

#pragma mark - Listener Registry

- (id<LAListener>)listenerForName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        return [self hasListenerWithName:name] ? self.remoteListener : nil;
    }
    return [self.backend listenerForName:name];
}

- (BOOL)hasListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageHasListener userInfo:userInfo defaultValue:NO];
    }
    return [self.backend hasListenerWithName:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    BOOL changedAvailability = [self.backend registerListener:listener forName:name markSeen:YES];
    if (listener && name.length > 0) {
        [self la_clearListenerMetadataCaches];
    }
    if (changedAvailability) {
        [self la_postSystemNotificationName:LAActivatorAvailableListenersChangedNotification];
    }
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    BOOL changedAvailability = [self.backend registerListener:listener forName:name markSeen:!ignoreHasSeen];
    if (listener && name.length > 0) {
        [self la_clearListenerMetadataCaches];
    }
    if (changedAvailability) {
        [self la_postSystemNotificationName:LAActivatorAvailableListenersChangedNotification];
    }
}

- (void)unregisterListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend unregisterListenerWithName:name]) {
        [self la_clearListenerMetadataCaches];
        [self la_postSystemNotificationName:LAActivatorAvailableListenersChangedNotification];
    }
}

- (BOOL)hasSeenListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageHasSeenListener userInfo:userInfo defaultValue:NO];
    }
    return [self.backend hasSeenListenerWithName:name];
}

#pragma mark - Assignment Model

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
    if (listenerName.length > 0) {
        [self assignEvent:event toListenersWithNames:@[ listenerName ]];
    } else {
        [self unassignEvent:event];
    }
}

- (void)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    [self la_assignEventAndNotifyIfChanged:event toListenersWithNames:listenerNames];
}

- (BOOL)la_assignEventAndNotifyIfChanged:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    BOOL changed = [self la_assignEvent:event toListenersWithNames:listenerNames];
    if (changed) {
        [self la_postSystemNotificationName:LAActivatorAssignmentsChangedNotification];
    }
    return changed;
}

- (BOOL)la_assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    if (event.name.length == 0) {
        return NO;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAIPCKeyListenerNames] = [LARuntimeBackend normalizedStringArray:listenerNames];
        return [self.ipcClient boolValueForMessageName:LAIPCMessageAssignEvent userInfo:userInfo defaultValue:NO];
    }
    if (event.mode.length > 0) {
        return [self la_assignEventWithExplicitMode:event toListenersWithNames:listenerNames];
    }

    BOOL changed = NO;
    for (NSString *mode in [self compatibleModesForEventWithName:event.name]) {
        LAEvent *modeEvent = [LAEvent eventWithName:event.name mode:mode];
        changed = [self la_assignEventWithExplicitMode:modeEvent toListenersWithNames:listenerNames] || changed;
    }
    return changed;
}

- (BOOL)la_assignEventWithExplicitMode:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    return [self.backend assignEvent:event toListenersWithNames:listenerNames];
}

- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event {
    [self la_addListenerAssignmentAndNotifyIfChanged:listenerName toEvent:event];
}

- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event {
    [self la_removeListenerAssignmentAndNotifyIfChanged:listenerName fromEvent:event];
}

- (BOOL)la_addListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName toEvent:(LAEvent *)event {
    BOOL changed = [self la_addListenerAssignment:listenerName toEvent:event];
    if (changed) {
        [self la_postSystemNotificationName:LAActivatorAssignmentsChangedNotification];
    }
    return changed;
}

- (BOOL)la_removeListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName fromEvent:(LAEvent *)event {
    BOOL changed = [self la_removeListenerAssignment:listenerName fromEvent:event];
    if (changed) {
        [self la_postSystemNotificationName:LAActivatorAssignmentsChangedNotification];
    }
    return changed;
}

- (BOOL)la_addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event {
    if (listenerName.length == 0 || event.name.length == 0) {
        return NO;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAIPCKeyListenerName] = listenerName ?: @"";
        return [self.ipcClient boolValueForMessageName:LAIPCMessageAddListenerAssignment
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    if (event.mode.length > 0) {
        return [self la_addListenerAssignmentWithExplicitMode:listenerName toEvent:event];
    }

    BOOL changed = NO;
    for (NSString *mode in [self compatibleModesForEventWithName:event.name]) {
        LAEvent *modeEvent = [LAEvent eventWithName:event.name mode:mode];
        changed = [self la_addListenerAssignmentWithExplicitMode:listenerName toEvent:modeEvent] || changed;
    }
    return changed;
}

- (BOOL)la_addListenerAssignmentWithExplicitMode:(NSString *)listenerName toEvent:(LAEvent *)event {
    return [self.backend addListenerName:listenerName toEvent:event];
}

- (BOOL)la_removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event {
    if (listenerName.length == 0 || event.name.length == 0) {
        return NO;
    }
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAIPCKeyListenerName] = listenerName ?: @"";
        return [self.ipcClient boolValueForMessageName:LAIPCMessageRemoveListenerAssignment
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    if (event.mode.length > 0) {
        return [self la_removeListenerAssignmentWithExplicitMode:listenerName fromEvent:event];
    }

    BOOL changed = NO;
    for (NSString *mode in self.availableEventModes) {
        LAEvent *modeEvent = [LAEvent eventWithName:event.name mode:mode];
        changed = [self la_removeListenerAssignmentWithExplicitMode:listenerName fromEvent:modeEvent] || changed;
    }
    return changed;
}

- (BOOL)la_removeListenerAssignmentWithExplicitMode:(NSString *)listenerName fromEvent:(LAEvent *)event {
    return [self.backend removeListenerName:listenerName fromEvent:event];
}

- (void)unassignEvent:(LAEvent *)event {
    [self la_unassignEventAndNotifyIfChanged:event];
}

- (BOOL)la_unassignEventAndNotifyIfChanged:(LAEvent *)event {
    BOOL changed = [self la_unassignEvent:event];
    if (changed) {
        [self la_postSystemNotificationName:LAActivatorAssignmentsChangedNotification];
    }
    return changed;
}

- (BOOL)la_unassignEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return NO;
    }
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAIPCMessageUnassignEvent
                                              userInfo:[self la_ipcUserInfoForEvent:event]
                                          defaultValue:NO];
    }
    if (event.mode.length > 0) {
        return [self la_unassignEventWithExplicitMode:event];
    }

    BOOL changed = NO;
    for (NSString *mode in self.availableEventModes) {
        LAEvent *modeEvent = [LAEvent eventWithName:event.name mode:mode];
        changed = [self la_unassignEventWithExplicitMode:modeEvent] || changed;
    }
    return changed;
}

- (BOOL)la_unassignEventWithExplicitMode:(LAEvent *)event {
    return [self.backend unassignEvent:event];
}

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event {
    return [[self assignedListenerNamesForEvent:event] firstObject];
}

- (NSArray *)la_compatibleAssignedListenerNames:(NSArray *)listenerNames forEvent:(LAEvent *)event {
    NSString *eventMode = event.mode ?: self.currentEventMode;
    if (event.name.length == 0 || eventMode.length == 0) {
        return @[];
    }

    NSMutableArray *compatibleNames = [NSMutableArray arrayWithCapacity:listenerNames.count];
    for (NSString *listenerName in listenerNames) {
        if (![listenerName isKindOfClass:NSString.class] || listenerName.length == 0) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithMode:eventMode]) {
            continue;
        }
        if (![self listenerWithName:listenerName isCompatibleWithEventName:event.name]) {
            continue;
        }
        [compatibleNames addObject:listenerName];
    }
    return [compatibleNames copy];
}

- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event {
    if (event.name.length > 0 && event.mode.length == 0) {
        NSString *eventMode = self.currentEventMode;
        if (eventMode.length == 0) {
            return @[];
        }
        event = [LAEvent eventWithName:event.name mode:eventMode];
    }
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageAssignedListenerNames
                                               userInfo:[self la_ipcUserInfoForEvent:event]];
    }
    return [self la_compatibleAssignedListenerNames:[self.backend assignedListenerNamesForEvent:event] forEvent:event];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient eventsValueForMessageName:LAIPCMessageEventsAssignedToListener userInfo:userInfo];
    }
    NSSet *availableEventNames = [NSSet setWithArray:self.availableEventNames];
    NSMutableArray *availableEvents = [[NSMutableArray alloc] init];
    for (LAEvent *event in [self.backend eventsAssignedToListenerWithName:listenerName]) {
        if ([availableEventNames containsObject:event.name]) {
            [availableEvents addObject:event];
        }
    }
    return [availableEvents copy];
}

#pragma mark - Event Registry

- (NSArray *)availableEventNames {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageAvailableEventNames userInfo:nil];
    }
    return [self.backend availableEventNames];
}

- (BOOL)hasEventWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageHasEvent userInfo:userInfo defaultValue:NO];
    }
    return [self.backend hasEventWithName:name];
}

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return nil;
    }
    return [self.backend eventDataSourceForEventName:eventName];
}

- (BOOL)eventWithNameIsHidden:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageEventIsHidden userInfo:userInfo defaultValue:NO];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameIsHidden:)]) {
        return [dataSource eventWithNameIsHidden:name];
    }
    return NO;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageEventRequiresAssignment
                                              userInfo:userInfo
                                          defaultValue:YES];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameRequiresAssignment:)]) {
        return [dataSource eventWithNameRequiresAssignment:name];
    }
    return YES;
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : name ?: @""};
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageCompatibleModesForEvent userInfo:userInfo];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (!dataSource) {
        return @[];
    }
    if (![dataSource respondsToSelector:@selector(eventWithName:isCompatibleWithMode:)]) {
        return self.availableEventModes;
    }

    NSMutableArray *modes = [NSMutableArray array];
    for (NSString *mode in self.availableEventModes) {
        if ([dataSource eventWithName:name isCompatibleWithMode:mode]) {
            [modes addObject:mode];
        }
    }
    return [modes copy];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [@{LAIPCKeyEventName : eventName ?: @""} mutableCopy];
        if (eventMode.length > 0) {
            userInfo[LAIPCKeyEventMode] = eventMode;
        }
        return [self.ipcClient boolValueForMessageName:LAIPCMessageEventIsCompatibleWithMode
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    if (eventName.length == 0) {
        return NO;
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (!dataSource) {
        return NO;
    }
    if ([dataSource respondsToSelector:@selector(eventWithName:isCompatibleWithMode:)]) {
        return [dataSource eventWithName:eventName isCompatibleWithMode:eventMode];
    }
    return eventMode.length == 0 || [self.availableEventModes containsObject:eventMode];
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageEventSupportsUnlockingDeviceToSend
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameSupportsUnlockingDeviceToSend:)]) {
        return [dataSource eventWithNameSupportsUnlockingDeviceToSend:eventName];
    }
    return NO;
}

- (NSString *)assignmentWarningForEventWithName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        return [self.ipcClient stringValueForMessageName:LAIPCMessageAssignmentWarningForEvent userInfo:userInfo];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(assignmentWarningForEventWithName:)]) {
        return [dataSource assignmentWarningForEventWithName:eventName];
    }
    return nil;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageEventSupportsRemoval
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameSupportsRemoval:)]) {
        return [dataSource eventWithNameSupportsRemoval:eventName];
    }
    return NO;
}

- (void)removeEventWithName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        [self.ipcClient sendMessageName:LAIPCMessageRemoveEvent userInfo:userInfo];
        return;
    }
    if (![self eventWithNameSupportsRemoval:eventName]) {
        return;
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(removeEventWithName:)]) {
        [dataSource removeEventWithName:eventName];
    }
    [self unregisterEventDataSourceWithEventName:eventName];
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend registerEventDataSource:dataSource forEventName:eventName]) {
        [self la_postSystemNotificationName:LAActivatorAvailableEventsChangedNotification];
    }
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend unregisterEventDataSourceWithEventName:eventName]) {
        [self la_postSystemNotificationName:LAActivatorAvailableEventsChangedNotification];
    }
}

- (BOOL)eventWithNameSupportsConfiguration:(NSString *)eventName {
    return NO;
}

- (LAEventConfigurationViewController *)configurationViewControllerForEventWithName:(NSString *)eventName {
    return nil;
}

#pragma mark - Listener Metadata

- (NSArray *)availableListenerNames {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageAvailableListenerNames userInfo:nil];
    }
    return [self.backend availableListenerNames];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAIPCKeyInfoDictionaryKey : key ?: @"",
            LAIPCKeyListenerName : name ?: @"",
        };
        return [self.ipcClient propertyListValueForMessageName:LAIPCMessageListenerInfoDictionaryValue
                                                      userInfo:userInfo];
    }
    id<LAListener> listener = [self listenerForName:name];
    if (listener &&
        [listener respondsToSelector:@selector(activator:requiresInfoDictionaryValueOfKey:forListenerWithName:)]) {
        id value = [listener activator:self requiresInfoDictionaryValueOfKey:key forListenerWithName:name];
        if (value) {
            return value;
        }
    }
    if ([key isEqualToString:@"title"]) {
        return [self localizedTitleForListenerName:name];
    }
    if ([key isEqualToString:@"description"]) {
        return [self localizedDescriptionForListenerName:name];
    }
    if ([key isEqualToString:@"group"]) {
        return [self localizedGroupForListenerName:name];
    }
    if ([key isEqualToString:@"requires-event"]) {
        return @([self listenerWithNameRequiresAssignment:name]);
    }
    if ([key isEqualToString:@"compatible-modes"]) {
        return [self compatibleEventModesForListenerWithName:name];
    }
    return [LAResourceManager.sharedManager infoDictionaryValueOfKey:key forListenerName:name];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerRequiresAssignment
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:requiresRequiresAssignmentForListenerName:)]) {
        NSNumber *value = [listener activator:self requiresRequiresAssignmentForListenerName:name];
        if (value) {
            return [value boolValue];
        }
    }
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"requires-event" forListenerName:name];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageCompatibleModesForListener
                                               userInfo:@{LAIPCKeyListenerName : name ?: @""}];
    }
    id<LAListener> listener = [self listenerForName:name];
    if (listener &&
        [listener respondsToSelector:@selector(activator:requiresCompatibleEventModesForListenerWithName:)]) {
        NSArray *modes = [LARuntimeBackend
            normalizedStringArray:[listener activator:self requiresCompatibleEventModesForListenerWithName:name]];
        if (modes.count > 0) {
            return modes;
        }
    }
    NSArray *resourceModes = [LARuntimeBackend
        normalizedStringArray:[LAResourceManager.sharedManager infoDictionaryValueOfKey:@"compatible-modes"
                                                                        forListenerName:name]];
    if (resourceModes.count > 0) {
        return resourceModes;
    }
    return [self hasListenerWithName:name] ? self.availableEventModes : @[];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(NSString *)eventMode {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAIPCKeyListenerName : listenerName ?: @"",
            LAIPCKeyEventMode : eventMode ?: @"",
        };
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerIsCompatibleWithMode
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    if (listenerName.length == 0 || eventMode.length == 0) {
        return NO;
    }
    return [[self compatibleEventModesForListenerWithName:listenerName] containsObject:eventMode];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAIPCKeyListenerName : listenerName ?: @"",
            LAIPCKeyEventName : eventName ?: @"",
        };
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerIsCompatibleWithEvent
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (!listener || eventName.length == 0) {
        return NO;
    }
    if ([listener respondsToSelector:@selector(activator:requiresIsCompatibleWithEventName:listenerName:)]) {
        NSNumber *value = [listener activator:self
            requiresIsCompatibleWithEventName:eventName
                                 listenerName:listenerName];
        if (value) {
            return [value boolValue];
        }
    }
    NSArray *incompatibleEvents = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"incompatible-events"
                                                                            forListenerName:listenerName];
    if ([incompatibleEvents isKindOfClass:NSArray.class] && [incompatibleEvents containsObject:eventName]) {
        return NO;
    }
    return YES;
}

- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerNeedsPoweredDisplay
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresNeedsPoweredDisplayForListenerName:)]) {
        return [listener activator:self requiresNeedsPoweredDisplayForListenerName:listenerName];
    }
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"needs-powered-display"
                                                         forListenerName:listenerName];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSArray *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageExclusiveAssignmentGroupsForListener
                                               userInfo:userInfo];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener &&
        [listener respondsToSelector:@selector(activator:requiresExclusiveAssignmentGroupsForListenerName:)]) {
        NSArray *groups =
            [LARuntimeBackend normalizedStringArray:[listener activator:self
                                                        requiresExclusiveAssignmentGroupsForListenerName:listenerName]];
        if (groups.count > 0) {
            return groups;
        }
    }
    return [LARuntimeBackend
        normalizedStringArray:[LAResourceManager.sharedManager infoDictionaryValueOfKey:@"exclusive-assignment-groups"
                                                                        forListenerName:listenerName]];
}

- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames {
    if (!self.runningInsideSpringBoard) {
        NSArray *normalizedNames = [LARuntimeBackend normalizedStringArray:listenerNames];
        NSDictionary *userInfo = @{LAIPCKeyListenerNames : normalizedNames};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerNamesAreMutuallyCompatible
                                              userInfo:userInfo
                                          defaultValue:YES];
    }
    NSArray *normalizedNames = [LARuntimeBackend normalizedStringArray:listenerNames];
    NSMutableDictionary *groupOwners = [NSMutableDictionary dictionary];
    for (NSString *listenerName in normalizedNames) {
        for (NSString *group in [self exclusiveAssignmentGroupsForListenerName:listenerName]) {
            NSString *owner = groupOwners[group];
            if (owner && ![owner isEqualToString:listenerName]) {
                return NO;
            }
            groupOwners[group] = listenerName;
        }
    }
    return YES;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName {
    return nil;
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName {
    return [self.listenerMetadataCache smallIconForListenerName:listenerName
                                                       resolver:^UIImage * {
                                                           return
                                                               [self la_resolveSmallIconForListenerName:listenerName];
                                                       }];
}

- (void)la_clearListenerMetadataCaches {
    [self.listenerMetadataCache removeAllObjects];
}

- (void)la_didReceiveMemoryWarning:(NSNotification *)notification {
    [self la_clearListenerMetadataCaches];
}

- (UIImage *)la_resolveSmallIconForListenerName:(NSString *)listenerName {
    CGFloat scale = UIScreen.mainScreen.scale;
    id<LAListener> listener = [self listenerForName:listenerName];
    if ([listener respondsToSelector:@selector(activator:requiresSmallIconForListenerName:scale:)]) {
        UIImage *image = [listener activator:self requiresSmallIconForListenerName:listenerName scale:scale];
        if (image) {
            return image;
        }
    }
    if ([listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:scale:)]) {
        NSData *data = [listener activator:self requiresSmallIconDataForListenerName:listenerName scale:&scale];
        if (data.length > 0) {
            return [UIImage imageWithData:data scale:scale > 0.0f ? scale : 1.0f];
        }
    }
    if ([listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:)]) {
        NSData *data = [listener activator:self requiresSmallIconDataForListenerName:listenerName];
        if (data.length > 0) {
            return [UIImage imageWithData:data scale:1.0f];
        }
    }
    return [LAResourceManager.sharedManager iconForListenerName:listenerName small:YES scale:scale];
}

- (NSData *)la_smallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
    if (!self.runningInsideSpringBoard || listenerName.length == 0) {
        return nil;
    }

    CGFloat actualScale = scale && *scale > 0.0f ? *scale : UIScreen.mainScreen.scale;
    NSData *data = nil;
    id<LAListener> listener = [self listenerForName:listenerName];
    if ([listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:scale:)]) {
        data = [listener activator:self requiresSmallIconDataForListenerName:listenerName scale:&actualScale];
    }
    if (data.length == 0 && [listener respondsToSelector:@selector(activator:requiresSmallIconDataForListenerName:)]) {
        data = [listener activator:self requiresSmallIconDataForListenerName:listenerName];
        actualScale = 1.0f;
    }
    if (data.length == 0) {
        data = [LAResourceManager.sharedManager iconDataForListenerName:listenerName small:YES scale:&actualScale];
    }
    if (scale) {
        *scale = actualScale;
    }
    return data.length > 0 ? data : nil;
}

- (UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle {
    NSString *path = [templateBundle pathForResource:@"icon" ofType:@"png"]
                         ?: [templateBundle pathForResource:@"Icon" ofType:@"png"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageListenerSupportsRemoval
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresSupportsRemovalForListenerWithName:)]) {
        return [listener activator:self requiresSupportsRemovalForListenerWithName:listenerName];
    }
    return [[LAResourceManager.sharedManager infoDictionaryValueOfKey:@"supports-removal"
                                                      forListenerName:listenerName] boolValue];
}

- (void)requestRemovalForListenerWithName:(NSString *)listenerName {
    if (![self listenerWithNameSupportsRemoval:listenerName]) {
        return;
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requestsRemovalForListenerWithName:)]) {
        [listener activator:self requestsRemovalForListenerWithName:listenerName];
    }
}

- (BOOL)listenerWithNameSupportsConfiguration:(NSString *)listenerName {
    return NO;
}

- (LAListenerConfigurationViewController *)configurationViewControllerForListenerWithName:(NSString *)listenerName {
    return nil;
}

#pragma mark - Event Modes

- (NSArray *)availableEventModes {
    return @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
}

- (NSString *)currentEventMode {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient stringValueForMessageName:LAIPCMessageCurrentEventMode userInfo:nil]
                   ?: LAEventModeSpringBoard;
    }
    return [self.runtimeStateProvider currentEventMode] ?: LAEventModeSpringBoard;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient stringValueForMessageName:LAIPCMessageCurrentEventModeUnderneathLockScreen userInfo:nil]
                   ?: LAEventModeSpringBoard;
    }
    return [self.runtimeStateProvider currentEventModeUnderneathLockScreen] ?: LAEventModeSpringBoard;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAIPCMessageSupportsUnlockingDeviceToSendEvents
                                              userInfo:nil
                                          defaultValue:NO];
    }
    return [self.runtimeStateProvider supportsUnlockingDeviceToSendEvents];
}

#pragma mark - Blacklist

- (NSString *)displayIdentifierForCurrentApplication {
    if (!self.runningInsideSpringBoard) {
        NSString *displayIdentifier =
            [self.ipcClient stringValueForMessageName:LAIPCMessageCurrentApplicationDisplayIdentifier userInfo:nil];
        return displayIdentifier.length > 0 ? displayIdentifier : nil;
    }
    return [self.runtimeStateProvider displayIdentifierForCurrentApplication];
}

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAIPCMessageApplicationIsBlacklisted
                                              userInfo:@{LAIPCKeyDisplayIdentifier : displayIdentifier ?: @""}
                                          defaultValue:NO];
    }
    return [self.backend applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier];
}

- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    [self la_setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:blacklisted];
}

- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAIPCKeyDisplayIdentifier : displayIdentifier ?: @"",
            LAIPCKeyBlacklisted : @(blacklisted),
        };
        return [self.ipcClient boolValueForMessageName:LAIPCMessageSetApplicationBlacklisted
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:blacklisted];
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAIPCMessageAvailableProfileNames userInfo:nil];
    }
    return [self.backend availableProfileNames];
}

- (NSString *)currentProfileName {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient stringValueForMessageName:LAIPCMessageCurrentProfileName userInfo:nil] ?: @"Default";
    }
    return self.backend.currentProfileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    [self la_setCurrentProfileName:currentProfileName];
}

- (BOOL)la_setCurrentProfileName:(NSString *)currentProfileName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyProfileName : currentProfileName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAIPCMessageSetCurrentProfileName
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend setCurrentProfileNameIfChanged:currentProfileName];
}

#pragma mark - Authorization

- (LAAuthorizationStatus)authorizationStatus {
    return LAAuthorizationStatusAuthorized;
}

- (void)requestAuthorization {
}

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value {
    return [LAResourceManager.sharedManager localizedStringForKey:key value:value];
}

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode {
    if ([eventMode isEqualToString:LAEventModeSpringBoard]) {
        return [self localizedStringForKey:@"MODE_TITLE_springboard" value:@"At Home Screen"];
    }
    if ([eventMode isEqualToString:LAEventModeApplication]) {
        return [self localizedStringForKey:@"MODE_TITLE_application" value:@"In Application"];
    }
    if ([eventMode isEqualToString:LAEventModeLockScreen]) {
        return [self localizedStringForKey:@"MODE_TITLE_lockscreen" value:@"At Lock Screen"];
    }
    return [self localizedStringForKey:@"MODE_TITLE_all" value:@"Anytime"];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        NSString *title = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedTitleForEventName
                                                           userInfo:userInfo];
        return title ?: [self localizedStringForKey:eventName value:eventName];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedTitleForEventName:eventName];
    }
    return [LAResourceManager.sharedManager localizedTitleForEventName:eventName];
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName {
    return [self.listenerMetadataCache
        localizedTitleForListenerName:listenerName
                             resolver:^NSString * {
                                 return [self la_resolveLocalizedTitleForListenerName:listenerName];
                             }];
}

- (NSString *)la_resolveLocalizedTitleForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        NSString *title = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedTitleForListenerName
                                                           userInfo:userInfo];
        return title ?: [self localizedStringForKey:listenerName value:listenerName];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedTitleForListenerName:)]) {
        NSString *title = [listener activator:self requiresLocalizedTitleForListenerName:listenerName];
        if (title.length > 0) {
            return title;
        }
    }
    return [LAResourceManager.sharedManager localizedTitleForListenerName:listenerName];
}

- (NSString *)localizedTitleForListenerNames:(NSArray *)listenerNames {
    if (!self.runningInsideSpringBoard) {
        NSMutableArray *names = [NSMutableArray arrayWithCapacity:listenerNames.count];
        for (id listenerName in listenerNames) {
            if ([listenerName isKindOfClass:NSString.class] && [listenerName length] > 0) {
                [names addObject:listenerName];
            }
        }
        NSDictionary *userInfo = @{LAIPCKeyListenerNames : names};
        NSString *title = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedTitleForListenerNames
                                                           userInfo:userInfo];
        if (title) {
            return title;
        }
    }
    NSMutableArray *localizedNames = [NSMutableArray arrayWithCapacity:listenerNames.count];
    for (NSString *listenerName in listenerNames) {
        [localizedNames addObject:[self localizedTitleForListenerName:listenerName]];
    }
    return [localizedNames componentsJoinedByString:@", "];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        NSString *groupName = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedGroupForEventName
                                                               userInfo:userInfo];
        return groupName ?: @"";
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedGroupForEventName:eventName] ?: @"";
    }
    return [LAResourceManager.sharedManager localizedGroupForEventName:eventName] ?: @"";
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName {
    return [self.listenerMetadataCache
        localizedGroupForListenerName:listenerName
                             resolver:^NSString * {
                                 return [self la_resolveLocalizedGroupForListenerName:listenerName];
                             }];
}

- (NSString *)la_resolveLocalizedGroupForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        NSString *groupName = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedGroupForListenerName
                                                               userInfo:userInfo];
        return groupName ?: @"";
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedGroupForListenerName:)]) {
        NSString *group = [listener activator:self requiresLocalizedGroupForListenerName:listenerName];
        if (group.length > 0) {
            return group;
        }
    }
    return [LAResourceManager.sharedManager localizedGroupForListenerName:listenerName] ?: @"";
}

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode {
    if ([eventMode isEqualToString:LAEventModeSpringBoard]) {
        return [self localizedStringForKey:@"MODE_DESCRIPTION_springboard" value:@"When SpringBoard icons are visible"];
    }
    if ([eventMode isEqualToString:LAEventModeApplication]) {
        return [self localizedStringForKey:@"MODE_DESCRIPTION_application" value:@"When an application is visible"];
    }
    if ([eventMode isEqualToString:LAEventModeLockScreen]) {
        return [self localizedStringForKey:@"MODE_DESCRIPTION_lockscreen"
                                     value:@"When is locked and lock screen is visible"];
    }
    return [self localizedStringForKey:@"MODE_DESCRIPTION_all" value:@""];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyEventName : eventName ?: @""};
        NSString *description = [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedDescriptionForEventName
                                                                 userInfo:userInfo];
        return description ?: [self localizedTitleForEventName:eventName];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedDescriptionForEventName:eventName] ?: [self localizedTitleForEventName:eventName];
    }
    return [LAResourceManager.sharedManager localizedDescriptionForEventName:eventName]
               ?: [self localizedTitleForEventName:eventName];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName {
    return [self.listenerMetadataCache
        localizedDescriptionForListenerName:listenerName
                                   resolver:^NSString * {
                                       return [self la_resolveLocalizedDescriptionForListenerName:listenerName];
                                   }];
}

- (NSString *)la_resolveLocalizedDescriptionForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAIPCKeyListenerName : listenerName ?: @""};
        NSString *description =
            [self.ipcClient stringValueForMessageName:LAIPCMessageLocalizedDescriptionForListenerName
                                             userInfo:userInfo];
        return description ?: [self localizedTitleForListenerName:listenerName];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedDescriptionForListenerName:)]) {
        NSString *description = [listener activator:self requiresLocalizedDescriptionForListenerName:listenerName];
        if (description.length > 0) {
            return description;
        }
    }
    return [LAResourceManager.sharedManager localizedDescriptionForListenerName:listenerName]
               ?: [self localizedTitleForListenerName:listenerName];
}

@end
