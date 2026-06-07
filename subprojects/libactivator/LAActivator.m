//
//  LAActivator.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <dispatch/dispatch.h>

#import "LAActivatorBackend.h"
#import "LAActivatorIPC.h"
#import "LAActivatorPersistence.h"
#import "LAActivatorPrivate.h"
#import "LAActivatorResourceManager.h"
#import "LAActivatorRuntimeStateProvider.h"
#import "LADefaultEventDataSource.h"
#import "LARemoteListener.h"
#import "LATouchActivityTracker.h"

#pragma mark - Private Interfaces

@interface UIImage (LAActivatorApplicationIcon)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

#pragma mark - Class Extension

@interface LAActivator ()
@property(nonatomic, strong) LAActivatorBackend *backend;
@property(nonatomic, strong) LAActivatorIPCClient *ipcClient;
@property(nonatomic, strong) LAActivatorIPCServer *ipcServer;
@property(nonatomic, strong) LAActivatorRuntimeStateProvider *runtimeStateProvider;
@property(nonatomic, strong) LATouchActivityTracker *touchActivityTracker;
- (BOOL)la_assignEventWithExplicitMode:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)la_unassignEventWithExplicitMode:(LAEvent *)event;
- (NSArray *)la_dispatchableListenerNames:(NSArray *)listenerNames forEvent:(LAEvent *)event;
- (void)la_sendEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames allowDeferral:(BOOL)allowDeferral;
- (void)la_sendUnlockingEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames eventMode:(NSString *)eventMode;
- (BOOL)la_listenerWithNameRequiresNoTouchEvents:(NSString *)listenerName;
- (void)la_sendAbortEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames;
- (void)la_notifyEventModeChanged:(NSString *)eventMode;
- (void)la_notifyListenersThatListener:(id<LAListener>)handlingListener handledEvent:(LAEvent *)event;
- (void)la_rejectSpringBoardOnlySelector:(SEL)selector;
- (id)la_ipcPropertyListValue:(id)value;
- (NSDictionary *)la_ipcUserInfoForEvent:(LAEvent *)event;
- (NSArray *)la_ipcOrderedStringArray:(NSArray *)array;
@end

@implementation LAActivator

#pragma mark - Lifecycle

LAActivator *LASharedActivator;

+ (void)load {
    [self sharedInstance];
}

+ (LAActivator *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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
        if (self.runningInsideSpringBoard) {
            _runtimeStateProvider = [[LAActivatorRuntimeStateProvider alloc] init];
            _backend = [[LAActivatorBackend alloc] initWithPersistence:[LAActivatorPersistence defaultPersistence]];
            _touchActivityTracker = [[LATouchActivityTracker alloc] init];
            __weak typeof(self) weakSelf = self;
            [_runtimeStateProvider setEventModeChangeHandler:^(NSString *eventMode) {
                [weakSelf la_notifyEventModeChanged:eventMode];
            }];
            [LADefaultEventDataSource.sharedDataSource registerAvailableEventsWithActivator:self];
        } else {
            _ipcClient = [[LAActivatorIPCClient alloc] init];
        }
    }
    return self;
}

#pragma mark - Runtime State

- (LAActivatorVersion)version {
    return LAActivatorVersion_2_0;
}

- (BOOL)isRunningInsideSpringBoard {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

- (BOOL)isDangerousToSendEvents {
    return NO;
}

- (void)startIPCServerIfNeeded {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    if (!self.ipcServer) {
        self.ipcServer = [[LAActivatorIPCServer alloc] initWithActivator:self];
    }
    [self.ipcServer start];
}

- (void)la_noteHomeScreenVisible:(BOOL)visible {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteHomeScreenVisible:visible];
}

- (void)la_noteLockScreenVisible:(BOOL)visible {
    if (!self.runningInsideSpringBoard) {
        return;
    }
    [self.runtimeStateProvider noteLockScreenVisible:visible];
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

#pragma mark - Event Delivery

- (id<LAListener>)listenerForEvent:(LAEvent *)event {
    NSString *listenerName = [self assignedListenerNameForEvent:event];
    return [self listenerForName:listenerName];
}

- (void)sendEventToListener:(LAEvent *)event {
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAActivatorIPCMessageDispatchAssignedEvent
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
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAActivatorIPCKeyListenerNames] = [self la_ipcOrderedStringArray:listenerNames];
        [self.ipcClient sendEventMessageName:LAActivatorIPCMessageDispatchEventToListeners
                                    userInfo:userInfo
                                       event:event];
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
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAActivatorIPCMessageDispatchAssignedAbortEvent
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
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAActivatorIPCKeyListenerNames] = [self la_ipcOrderedStringArray:listenerNames];
        [self.ipcClient sendEventMessageName:LAActivatorIPCMessageDispatchAbortEventToListeners
                                    userInfo:userInfo
                                       event:event];
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        [self.ipcClient sendMessageName:LAActivatorIPCMessageDispatchPreviewEvent userInfo:userInfo];
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
    if (!self.runningInsideSpringBoard) {
        [self.ipcClient sendEventMessageName:LAActivatorIPCMessageDispatchDeactivateEvent
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
    if (!event) {
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
        [dispatchableNames addObject:listenerName];
    }
    return [dispatchableNames copy];
}

- (void)la_sendEvent:(LAEvent *)event toListenerNames:(NSArray *)listenerNames allowDeferral:(BOOL)allowDeferral {
    if (!self.runningInsideSpringBoard || !event) {
        return;
    }

    NSString *eventMode = event.mode ?: self.currentEventMode;
    if ([eventMode isEqualToString:LAEventModeLockScreen]) {
        [self la_sendUnlockingEvent:event toListenerNames:listenerNames eventMode:eventMode];
    }

    NSString *displayIdentifier = self.displayIdentifierForCurrentApplication;
    if (displayIdentifier.length > 0 && [self applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier]) {
        return;
    }

    NSArray *dispatchableListenerNames = [self la_dispatchableListenerNames:listenerNames forEvent:event];
    if (allowDeferral && self.touchActivityTracker.touchActive) {
        NSString *deferredListenerName = nil;
        for (NSString *listenerName in dispatchableListenerNames) {
            if ([self la_listenerWithNameRequiresNoTouchEvents:listenerName]) {
                deferredListenerName = listenerName;
                break;
            }
        }
        if (deferredListenerName.length > 0) {
            LAEvent *deferredEvent = [LAEvent eventWithName:event.name mode:eventMode];
            deferredEvent.userInfo = event.userInfo;
            event.handled = YES;
            [self la_notifyListenersThatListener:[self listenerForName:deferredListenerName] handledEvent:event];
            __weak typeof(self) weakSelf = self;
            [self.touchActivityTracker performWhenTouchesEnd:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf la_sendEvent:deferredEvent toListenerNames:dispatchableListenerNames allowDeferral:NO];
            }];
            return;
        }
    }

    for (NSString *listenerName in dispatchableListenerNames) {
        id<LAListener> listener = [self listenerForName:listenerName];
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

- (void)la_sendUnlockingEvent:(LAEvent *)event
              toListenerNames:(NSArray *)listenerNames
                    eventMode:(NSString *)eventMode {
    if (![eventMode isEqualToString:LAEventModeLockScreen] || !self.supportsUnlockingDeviceToSendEvents ||
        ![self eventWithNameSupportsUnlockingDeviceToSend:event.name]) {
        return;
    }

    NSString *underneathMode = self.currentEventModeUnderneathLockScreen;
    if (underneathMode.length == 0 || [underneathMode isEqualToString:LAEventModeLockScreen]) {
        return;
    }

    NSMutableSet *seenNames = [NSMutableSet set];
    for (id value in listenerNames) {
        if (![value isKindOfClass:NSString.class] || [value length] == 0 || [seenNames containsObject:value]) {
            continue;
        }
        NSString *listenerName = value;
        [seenNames addObject:listenerName];

        id<LAListener> listener = [self listenerForName:listenerName];
        if (!listener || ![listener respondsToSelector:@selector(activator:
                                                           receiveUnlockingDeviceEvent:forListenerName:)]) {
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
        }
        if (!wasHandled && event.handled) {
            [self la_notifyListenersThatListener:listener handledEvent:event];
        }
    }
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

- (void)la_notifyEventModeChanged:(NSString *)eventMode {
    if (!self.runningInsideSpringBoard || eventMode.length == 0) {
        return;
    }

    for (id<LAListener> listener in [self.backend registeredListeners]) {
        if ([listener respondsToSelector:@selector(activator:didChangeToEventMode:)]) {
            [listener activator:self didChangeToEventMode:eventMode];
        }
    }
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
    NSLog(@"libactivator: -[LAActivator %@] is only available inside SpringBoard. This call was ignored.",
          NSStringFromSelector(selector));
}

#pragma mark - IPC Serialization

- (id)la_ipcPropertyListValue:(id)value {
    if (!value) {
        return nil;
    }

    BOOL isValidValue = [NSPropertyListSerialization propertyList:value
                                                 isValidForFormat:NSPropertyListBinaryFormat_v1_0];

    return (isValidValue ? value : nil);
}

- (NSDictionary *)la_ipcUserInfoForEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @{};
    }

    NSMutableDictionary *userInfo = [@{LAActivatorIPCKeyEventName : event.name} mutableCopy];
    if (event.mode.length > 0) {
        userInfo[LAActivatorIPCKeyEventMode] = event.mode;
    }
    userInfo[LAActivatorIPCKeyEventHandled] = @(event.handled);

    NSDictionary *eventUserInfo = [self la_ipcPropertyListValue:event.userInfo];
    if (eventUserInfo) {
        userInfo[LAActivatorIPCKeyEventUserInfo] = eventUserInfo;
    }
    return [userInfo copy];
}

- (NSArray *)la_ipcOrderedStringArray:(NSArray *)array {
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            [strings addObject:value];
        }
    }
    return [strings copy];
}

#pragma mark - Listener Registry

- (id<LAListener>)listenerForName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        return [self hasListenerWithName:name] ? [LARemoteListener sharedListener] : nil;
    }
    return [self.backend listenerForName:name];
}

- (BOOL)hasListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageHasListener
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend hasListenerWithName:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend registerListener:listener forName:name]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                          object:self];
    }
}

- (void)unregisterListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend unregisterListenerWithName:name]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                          object:self];
    }
}

- (BOOL)hasSeenListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageHasSeenListener
                                              userInfo:userInfo
                                          defaultValue:NO];
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
    if ([self la_assignEvent:event toListenersWithNames:listenerNames]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
    }
}

- (BOOL)la_assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    if (event.name.length == 0) {
        return NO;
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
    if (!self.runningInsideSpringBoard) {
        NSMutableDictionary *userInfo = [[self la_ipcUserInfoForEvent:event] mutableCopy];
        userInfo[LAActivatorIPCKeyListenerNames] = [LAActivatorBackend normalizedStringArray:listenerNames];
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageAssignEvent
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend assignEvent:event toListenersWithNames:listenerNames];
}

- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event {
    if (listenerName.length == 0) {
        return;
    }
    NSMutableArray *listenerNames = [[self assignedListenerNamesForEvent:event] mutableCopy];
    if (![listenerNames containsObject:listenerName]) {
        [listenerNames addObject:listenerName];
        [self assignEvent:event toListenersWithNames:listenerNames];
    }
}

- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event {
    if (listenerName.length == 0) {
        return;
    }
    NSMutableArray *listenerNames = [[self assignedListenerNamesForEvent:event] mutableCopy];
    [listenerNames removeObject:listenerName];
    [self assignEvent:event toListenersWithNames:listenerNames];
}

- (void)unassignEvent:(LAEvent *)event {
    if ([self la_unassignEvent:event]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
    }
}

- (BOOL)la_unassignEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return NO;
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
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageUnassignEvent
                                              userInfo:[self la_ipcUserInfoForEvent:event]
                                          defaultValue:NO];
    }
    return [self.backend unassignEvent:event];
}

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event {
    return [[self assignedListenerNamesForEvent:event] firstObject];
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
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageAssignedListenerNames
                                               userInfo:[self la_ipcUserInfoForEvent:event]];
    }
    return [self.backend assignedListenerNamesForEvent:event];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient eventsValueForMessageName:LAActivatorIPCMessageEventsAssignedToListener
                                                userInfo:@{LAActivatorIPCKeyListenerName : listenerName ?: @""}];
    }
    return [self.backend eventsAssignedToListenerWithName:listenerName];
}

#pragma mark - Event Registry

- (NSArray *)availableEventNames {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageAvailableEventNames userInfo:nil];
    }
    return [self.backend availableEventNames];
}

- (BOOL)hasEventWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageHasEvent
                                              userInfo:@{LAActivatorIPCKeyEventName : name ?: @""}
                                          defaultValue:NO];
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageEventIsHidden
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameIsHidden:)]) {
        return [dataSource eventWithNameIsHidden:name];
    }
    return NO;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageEventRequiresAssignment
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : name ?: @""};
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageCompatibleModesForEvent userInfo:userInfo];
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
        NSMutableDictionary *userInfo = [@{LAActivatorIPCKeyEventName : eventName ?: @""} mutableCopy];
        if (eventMode.length > 0) {
            userInfo[LAActivatorIPCKeyEventMode] = eventMode;
        }
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageEventIsCompatibleWithMode
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageEventSupportsUnlockingDeviceToSend
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameSupportsUnlockingDeviceToSend:)]) {
        return [dataSource eventWithNameSupportsUnlockingDeviceToSend:eventName];
    }
    return NO;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageEventSupportsRemoval
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        [self.ipcClient sendMessageName:LAActivatorIPCMessageRemoveEvent userInfo:userInfo];
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
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification
                                                          object:self];
    }
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if (!self.runningInsideSpringBoard) {
        [self la_rejectSpringBoardOnlySelector:_cmd];
        return;
    }
    if ([self.backend unregisterEventDataSourceWithEventName:eventName]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification
                                                          object:self];
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
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageAvailableListenerNames userInfo:nil];
    }
    return [self.backend availableListenerNames];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAActivatorIPCKeyInfoDictionaryKey : key ?: @"",
            LAActivatorIPCKeyListenerName : name ?: @"",
        };
        return [self.ipcClient propertyListValueForMessageName:LAActivatorIPCMessageListenerInfoDictionaryValue
                                                      userInfo:userInfo];
    }
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresInfoDictionaryValueOfKey:forListenerWithName:)]) {
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
    return [LAActivatorResourceManager.sharedManager infoDictionaryValueOfKey:key forListenerName:name];
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : name ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerRequiresAssignment
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
    id value = [LAActivatorResourceManager.sharedManager infoDictionaryValueOfKey:@"requires-event"
                                                                  forListenerName:name];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageCompatibleModesForListener
                                               userInfo:@{LAActivatorIPCKeyListenerName : name ?: @""}];
    }
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresCompatibleEventModesForListenerWithName:)]) {
        NSArray *modes = [LAActivatorBackend
            normalizedStringArray:[listener activator:self requiresCompatibleEventModesForListenerWithName:name]];
        if (modes.count > 0) {
            return modes;
        }
    }
    NSArray *resourceModes = [LAActivatorBackend
        normalizedStringArray:[LAActivatorResourceManager.sharedManager infoDictionaryValueOfKey:@"compatible-modes"
                                                                                 forListenerName:name]];
    if (resourceModes.count > 0) {
        return resourceModes;
    }
    return [self hasListenerWithName:name] ? self.availableEventModes : @[];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(NSString *)eventMode {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{
            LAActivatorIPCKeyListenerName : listenerName ?: @"",
            LAActivatorIPCKeyEventMode : eventMode ?: @"",
        };
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerIsCompatibleWithMode
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
            LAActivatorIPCKeyListenerName : listenerName ?: @"",
            LAActivatorIPCKeyEventName : eventName ?: @"",
        };
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerIsCompatibleWithEvent
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
    NSArray *incompatibleEvents =
        [LAActivatorResourceManager.sharedManager infoDictionaryValueOfKey:@"incompatible-events"
                                                           forListenerName:listenerName];
    if ([incompatibleEvents isKindOfClass:NSArray.class] && [incompatibleEvents containsObject:eventName]) {
        return NO;
    }
    return YES;
}

- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerNeedsPoweredDisplay
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresNeedsPoweredDisplayForListenerName:)]) {
        return [listener activator:self requiresNeedsPoweredDisplayForListenerName:listenerName];
    }
    return NO;
}

- (NSArray *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageExclusiveAssignmentGroupsForListener
                                               userInfo:userInfo];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresExclusiveAssignmentGroupsForListenerName:)]) {
        return [LAActivatorBackend
            normalizedStringArray:[listener activator:self
                                      requiresExclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    return @[];
}

- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames {
    if (!self.runningInsideSpringBoard) {
        NSArray *normalizedNames = [LAActivatorBackend normalizedStringArray:listenerNames];
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerNames : normalizedNames};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerNamesAreMutuallyCompatible
                                              userInfo:userInfo
                                          defaultValue:YES];
    }
    NSArray *normalizedNames = [LAActivatorBackend normalizedStringArray:listenerNames];
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
    CGFloat scale = UIScreen.mainScreen.scale;
    id<LAListener> listener = [self listenerForName:listenerName];
    if ([listener respondsToSelector:@selector(activator:requiresIconForListenerName:scale:)]) {
        UIImage *image = [listener activator:self requiresIconForListenerName:listenerName scale:scale];
        if (image) {
            return image;
        }
    }
    if ([listener respondsToSelector:@selector(activator:requiresIconDataForListenerName:scale:)]) {
        NSData *data = [listener activator:self requiresIconDataForListenerName:listenerName scale:&scale];
        if (data.length > 0) {
            return [UIImage imageWithData:data scale:scale > 0.0f ? scale : 1.0f];
        }
    }
    if ([listener respondsToSelector:@selector(activator:requiresIconDataForListenerName:)]) {
        NSData *data = [listener activator:self requiresIconDataForListenerName:listenerName];
        if (data.length > 0) {
            return [UIImage imageWithData:data scale:1.0f];
        }
    }
    return [LAActivatorResourceManager.sharedManager iconForListenerName:listenerName small:NO scale:scale];
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName {
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
    if (listenerName.length > 0 &&
        [UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
        UIImage *applicationIcon = [UIImage _applicationIconImageForBundleIdentifier:listenerName
                                                                              format:0
                                                                               scale:scale];
        if (applicationIcon) {
            return applicationIcon;
        }
    }
    return [LAActivatorResourceManager.sharedManager iconForListenerName:listenerName small:YES scale:scale];
}

- (UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle {
    UIImage *image = [self iconForListenerName:listenerName];
    if (image) {
        return image;
    }
    NSString *path = [templateBundle pathForResource:@"icon" ofType:@"png"]
                         ?: [templateBundle pathForResource:@"Icon" ofType:@"png"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageListenerSupportsRemoval
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresSupportsRemovalForListenerWithName:)]) {
        return [listener activator:self requiresSupportsRemovalForListenerWithName:listenerName];
    }
    return [[LAActivatorResourceManager.sharedManager infoDictionaryValueOfKey:@"supports-removal"
                                                               forListenerName:listenerName] boolValue];
}

- (void)requestRemovalForListenerWithName:(NSString *)listenerName {
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
        return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageCurrentEventMode userInfo:nil]
                   ?: [self.runtimeStateProvider currentEventMode];
    }
    return [self.runtimeStateProvider currentEventMode];
}

- (NSString *)currentEventModeUnderneathLockScreen {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageCurrentEventModeUnderneathLockScreen
                                                userInfo:nil]
                   ?: [self.runtimeStateProvider currentEventModeUnderneathLockScreen];
    }
    return [self.runtimeStateProvider currentEventModeUnderneathLockScreen];
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageSupportsUnlockingDeviceToSendEvents
                                              userInfo:nil
                                          defaultValue:NO];
    }
    return [self.runtimeStateProvider supportsUnlockingDeviceToSendEvents];
}

#pragma mark - Blacklist

- (NSString *)displayIdentifierForCurrentApplication {
    if (!self.runningInsideSpringBoard) {
        NSString *displayIdentifier =
            [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageCurrentApplicationDisplayIdentifier
                                             userInfo:nil];
        return displayIdentifier.length > 0 ? displayIdentifier : nil;
    }
    return [self.runtimeStateProvider displayIdentifierForCurrentApplication];
}

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageApplicationIsBlacklisted
                                              userInfo:@{LAActivatorIPCKeyDisplayIdentifier : displayIdentifier ?: @""}
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
            LAActivatorIPCKeyDisplayIdentifier : displayIdentifier ?: @"",
            LAActivatorIPCKeyBlacklisted : @(blacklisted),
        };
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageSetApplicationBlacklisted
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:blacklisted];
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient arrayValueForMessageName:LAActivatorIPCMessageAvailableProfileNames userInfo:nil];
    }
    return [self.backend availableProfileNames];
}

- (NSString *)currentProfileName {
    if (!self.runningInsideSpringBoard) {
        return [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageCurrentProfileName userInfo:nil]
                   ?: @"Default";
    }
    return self.backend.currentProfileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    [self la_setCurrentProfileName:currentProfileName];
}

- (BOOL)la_setCurrentProfileName:(NSString *)currentProfileName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyProfileName : currentProfileName ?: @""};
        return [self.ipcClient boolValueForMessageName:LAActivatorIPCMessageSetCurrentProfileName
                                              userInfo:userInfo
                                          defaultValue:NO];
    }
    return [self.backend setCurrentProfileNameIfChanged:currentProfileName];
}

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value {
    return [LAActivatorResourceManager.sharedManager localizedStringForKey:key value:value];
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        NSString *title = [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedTitleForEventName
                                                           userInfo:userInfo];
        return title ?: [self localizedStringForKey:eventName value:eventName];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedTitleForEventName:eventName];
    }
    return [LAActivatorResourceManager.sharedManager localizedTitleForEventName:eventName];
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        NSString *title = [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedTitleForListenerName
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
    return [LAActivatorResourceManager.sharedManager localizedTitleForListenerName:listenerName];
}

- (NSString *)localizedTitleForListenerNames:(NSArray *)listenerNames {
    if (!self.runningInsideSpringBoard) {
        NSMutableArray *names = [NSMutableArray arrayWithCapacity:listenerNames.count];
        for (id listenerName in listenerNames) {
            if ([listenerName isKindOfClass:NSString.class] && [listenerName length] > 0) {
                [names addObject:listenerName];
            }
        }
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerNames : names};
        NSString *title = [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedTitleForListenerNames
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        NSString *groupName = [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedGroupForEventName
                                                               userInfo:userInfo];
        return groupName ?: @"";
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedGroupForEventName:eventName] ?: @"";
    }
    return [LAActivatorResourceManager.sharedManager localizedGroupForEventName:eventName] ?: @"";
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        NSString *groupName =
            [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedGroupForListenerName
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
    return [LAActivatorResourceManager.sharedManager localizedGroupForListenerName:listenerName] ?: @"";
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
        NSDictionary *userInfo = @{LAActivatorIPCKeyEventName : eventName ?: @""};
        NSString *description =
            [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedDescriptionForEventName
                                             userInfo:userInfo];
        return description ?: [self localizedTitleForEventName:eventName];
    }
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [dataSource localizedDescriptionForEventName:eventName] ?: [self localizedTitleForEventName:eventName];
    }
    return [LAActivatorResourceManager.sharedManager localizedDescriptionForEventName:eventName]
               ?: [self localizedTitleForEventName:eventName];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName {
    if (!self.runningInsideSpringBoard) {
        NSDictionary *userInfo = @{LAActivatorIPCKeyListenerName : listenerName ?: @""};
        NSString *description =
            [self.ipcClient stringValueForMessageName:LAActivatorIPCMessageLocalizedDescriptionForListenerName
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
    return [LAActivatorResourceManager.sharedManager localizedDescriptionForListenerName:listenerName]
               ?: [self localizedTitleForListenerName:listenerName];
}

@end
