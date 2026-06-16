//
//  LATNetworkEventSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATNetworkEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"

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

// Lifecycle
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) BOOL refreshScheduled;

// Wi-Fi state
@property(nonatomic, assign) BOOL hasKnownWiFiNetworkName;
@property(nonatomic, copy, nullable) NSString *currentWiFiNetworkName;

// Observation tokens
@property(nonatomic, strong, nullable) id<NSObject> signalStrengthObserver;
@property(nonatomic, strong, nullable) id<NSObject> wakeFromSleepObserver;

// Path monitoring
@property(nonatomic, strong, nullable) nw_path_monitor_t pathMonitor;
@property(nonatomic, strong) dispatch_queue_t pathMonitorQueue;

@end

@implementation LATNetworkEventSource

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr =
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_UTILITY, 0);
        _pathMonitorQueue = dispatch_queue_create("libactivator.network-path", attr);
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownWiFiNetworkNameWithoutSendingEvent];
    [self startSpringBoardNetworkNotificationMonitoring];
    [self startPathMonitoring];
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    if (_signalStrengthObserver) {
        [notificationCenter removeObserver:_signalStrengthObserver];
    }
    if (_wakeFromSleepObserver) {
        [notificationCenter removeObserver:_wakeFromSleepObserver];
    }
    if (_pathMonitor) {
        nw_path_monitor_cancel(_pathMonitor);
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
            [self scheduleNetworkStateRefreshWithReason:reason];
        });
        return;
    }
    [self scheduleNetworkStateRefreshWithReason:reason];
}

- (void)scheduleNetworkStateRefreshWithReason:(NSString *)reason {
    LAAssertMainQueue();
    if (self.refreshScheduled) {
        return;
    }
    self.refreshScheduled = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATNetworkStateRefreshDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       self.refreshScheduled = NO;
                       [self handlePotentialNetworkStateChangeWithReason:reason];
                   });
}

#pragma mark - Wi-Fi State

- (void)handlePotentialNetworkStateChangeWithReason:(NSString *)reason {
    LAAssertMainQueue();

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

    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    if (networkName.length > 0) {
        NSString *specificEventName = [baseEventName stringByAppendingFormat:@".%@", networkName];
        LAEvent *specificEvent = [LAEvent eventWithName:specificEventName mode:eventMode];
        [LASharedActivator sendEventToListener:specificEvent];
        if (specificEvent.handled) {
            return;
        }
    }

    LAEvent *event = [LAEvent eventWithName:baseEventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
