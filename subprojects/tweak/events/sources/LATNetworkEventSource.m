//
//  LATNetworkEventSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATNetworkEventSource.h"

#import "LAQueueAssertions.h"
#import "LATNetworkEventDataSource.h"

#import <HBLog.h>
#import <Network/Network.h>

static NSString *const LATNetworkWiFiSignalStrengthChangedNotification = @"SBWifiSignalStrengthChangedNotification";
static NSString *const LATNetworkWakeFromSleepNotification = @"BKSPowerUtilitiesSystemDidWakeFromSleepNotification";
static NSTimeInterval const LATNetworkStateRefreshDelay = 0.1;

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (NSString *)currentNetworkName;
@end

@interface LATNetworkEventSource ()

// Dependencies
@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, strong) id<LATEventDefinitionQuerying> definitionQuerying;

// Lifecycle
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign) BOOL refreshScheduled;

// Wi-Fi state
@property(nonatomic, assign) BOOL hasKnownWiFiNetworkName;
@property(nonatomic, copy, nullable) NSString *currentWiFiNetworkName;
@property(nonatomic, copy, readwrite) NSSet<NSString *> *configuredEventNames;

// Observation tokens
@property(nonatomic, strong, nullable) id<NSObject> signalStrengthObserver;
@property(nonatomic, strong, nullable) id<NSObject> wakeFromSleepObserver;

// Path monitoring
@property(nonatomic, strong, nullable) nw_path_monitor_t pathMonitor;
@property(nonatomic, strong) dispatch_queue_t pathMonitorQueue;

@end

@implementation LATNetworkEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    return [self initWithEventDispatcher:context.eventDispatcher
                            modeProvider:context.eventDispatcher
                      definitionQuerying:context.eventDispatcher];
}

- (id<LATEventDefinitionProvider>)eventDefinitionProviderForContext:(LATEventSourceContext *)context {
    return [[LATNetworkEventDataSource alloc] initWithActivator:context.activator];
}

- (NSString *)eventSourceIdentifier {
    return @"network";
}

- (NSSet<NSString *> *)eventNames {
    NSMutableSet<NSString *> *eventNames = [NSMutableSet setWithArray:@[
        LAEventNameNetworkJoinedWiFi,
        LAEventNameNetworkLeftWiFi,
    ]];
    [eventNames unionSet:self.configuredEventNames];
    return [eventNames copy];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                     definitionQuerying:(id<LATEventDefinitionQuerying>)definitionQuerying {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);
    NSParameterAssert(definitionQuerying);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _definitionQuerying = definitionQuerying;
        dispatch_queue_attr_t attr =
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_UTILITY, 0);
        _pathMonitorQueue = dispatch_queue_create("libactivator.network-path", attr);
        _configuredEventNames = [NSSet set];
    }
    return self;
}

- (void)updateConfiguredEventNames:(NSSet<NSString *> *)configuredEventNames {
    LAAssertMainQueue();
    self.configuredEventNames = [configuredEventNames copy] ?: [NSSet set];
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
        return;
    }
    self.started = YES;

    [self refreshKnownWiFiNetworkNameWithoutSendingEvent];
    [self startSpringBoardNetworkNotificationMonitoring];
    [self startPathMonitoring];
}

- (void)dealloc {
    [self stopMonitoring];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    self.refreshScheduled = NO;
    [self stopMonitoring];
    self.hasKnownWiFiNetworkName = NO;
    self.currentWiFiNetworkName = nil;
}

- (void)stopMonitoring {
    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    if (_signalStrengthObserver) {
        [notificationCenter removeObserver:_signalStrengthObserver];
        _signalStrengthObserver = nil;
    }
    if (_wakeFromSleepObserver) {
        [notificationCenter removeObserver:_wakeFromSleepObserver];
        _wakeFromSleepObserver = nil;
    }
    if (_pathMonitor) {
        nw_path_monitor_cancel(_pathMonitor);
        _pathMonitor = nil;
    }
}

#pragma mark - Monitoring

- (void)startSpringBoardNetworkNotificationMonitoring {
    LAAssertMainQueue();

    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    __weak typeof(self) weakSelf = self;
    self.signalStrengthObserver =
        [notificationCenter addObserverForName:LATNetworkWiFiSignalStrengthChangedNotification
                                        object:nil
                                         queue:NSOperationQueue.mainQueue
                                    usingBlock:^(__unused NSNotification *notification) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        [strongSelf scheduleNetworkStateRefreshWithReason:@"wifi-signal-strength"];
                                    }];
    self.wakeFromSleepObserver =
        [notificationCenter addObserverForName:LATNetworkWakeFromSleepNotification
                                        object:nil
                                         queue:NSOperationQueue.mainQueue
                                    usingBlock:^(__unused NSNotification *notification) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        [strongSelf scheduleNetworkStateRefreshWithReason:@"wake-from-sleep"];
                                    }];
}

- (void)startPathMonitoring {
    nw_path_monitor_t monitor = nw_path_monitor_create();
    if (!monitor) {
        HBLogDebug(@"Unable to create Network path monitor for network event source");
        return;
    }

    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_queue(monitor, self.pathMonitorQueue);
    nw_path_monitor_set_update_handler(monitor, ^(__unused nw_path_t path) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf noteNetworkStateMayHaveChangedWithReason:@"nw-path"];
    });
    nw_path_monitor_start(monitor);
    self.pathMonitor = monitor;
}

- (void)noteNetworkStateMayHaveChangedWithReason:(NSString *)reason {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self noteNetworkStateMayHaveChangedWithReason:reason];
        });
        return;
    }
    if (!self.started) {
        return;
    }
    [self scheduleNetworkStateRefreshWithReason:reason];
}

- (void)scheduleNetworkStateRefreshWithReason:(NSString *)reason {
    LAAssertMainQueue();
    if (!self.started || self.refreshScheduled) {
        return;
    }
    self.refreshScheduled = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATNetworkStateRefreshDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       self.refreshScheduled = NO;
                       if (!self.started) {
                           return;
                       }
                       [self handlePotentialNetworkStateChangeWithReason:reason];
                   });
}

#pragma mark - Wi-Fi State

- (void)handlePotentialNetworkStateChangeWithReason:(NSString *)reason {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    NSString *networkName = [self readCurrentWiFiNetworkName];
    if (!self.hasKnownWiFiNetworkName) {
        self.hasKnownWiFiNetworkName = YES;
        self.currentWiFiNetworkName = networkName;
        return;
    }

    NSString *previousNetworkName = self.currentWiFiNetworkName;
    if ((previousNetworkName.length == 0 && networkName.length == 0) ||
        [previousNetworkName isEqualToString:networkName]) {
        return;
    }

    self.currentWiFiNetworkName = networkName;
    if (networkName.length > 0) {
        [self sendWiFiEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
    } else {
        [self sendWiFiEventWithBaseName:LAEventNameNetworkLeftWiFi networkName:previousNetworkName];
    }

    HBLogDebug(@"Network event source processed Wi-Fi change reason=%@ previous=%@ current=%@", reason ?: @"",
               previousNetworkName ?: @"", networkName ?: @"");
}

- (void)refreshKnownWiFiNetworkNameWithoutSendingEvent {
    LAAssertMainQueue();
    self.hasKnownWiFiNetworkName = YES;
    self.currentWiFiNetworkName = [self readCurrentWiFiNetworkName];
}

- (nullable NSString *)readCurrentWiFiNetworkName {
    LAAssertMainQueue();

    Class managerClass = NSClassFromString(@"SBWiFiManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }

    SBWiFiManager *manager = [(id)managerClass sharedInstance];
    if (![manager respondsToSelector:@selector(currentNetworkName)]) {
        return nil;
    }

    NSString *networkName = [manager currentNetworkName];
    return networkName.length > 0 ? networkName : nil;
}

#pragma mark - Event Dispatch

- (void)sendWiFiEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    if (networkName.length > 0) {
        NSString *specificEventName = [baseEventName stringByAppendingFormat:@".%@", networkName];
        if ([self.configuredEventNames containsObject:specificEventName] &&
            [self.definitionQuerying hasEventDefinitionWithName:specificEventName]) {
            LAEvent *specificEvent = [LAEvent eventWithName:specificEventName mode:eventMode];
            [self.eventDispatcher dispatchEvent:specificEvent];
            if (specificEvent.handled) {
                return;
            }
        }
    }

    LAEvent *event = [LAEvent eventWithName:baseEventName mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
}

#if LIBACTIVATOR_TEST_SUPPORT
- (void)la_testingSendWiFiEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName {
    LAAssertMainQueue();

    BOOL started = self.started;
    self.started = YES;
    [self sendWiFiEventWithBaseName:baseEventName networkName:networkName];
    self.started = started;
}
#endif

@end
