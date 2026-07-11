//
//  LATPowerStateEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATPowerStateEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface LATPowerStateEventSource ()

// Lifecycle
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

// External power state
@property(nonatomic, assign) BOOL hasKnownExternalPowerState;
@property(nonatomic, assign, getter=isExternallyPowered) BOOL externallyPowered;

// Observation token
@property(nonatomic, strong, nullable) id<NSObject> batteryStateObserver;
@property(nonatomic, assign) BOOL enabledBatteryMonitoring;

@end

@implementation LATPowerStateEventSource

#pragma mark - LATEventSource

- (NSString *)eventSourceIdentifier {
    return @"power-state";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNamePowerConnected,
        LAEventNamePowerDisconnected,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
        return;
    }
    self.started = YES;

    UIDevice *device = UIDevice.currentDevice;
    if (!device.batteryMonitoringEnabled) {
        device.batteryMonitoringEnabled = YES;
        self.enabledBatteryMonitoring = YES;
    }
    [self refreshKnownPowerStateWithoutSendingEventForDevice:device];

    __weak typeof(self) weakSelf = self;
    self.batteryStateObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                        object:device
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *notification) {
                                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                                        [strongSelf handleBatteryStateDidChangeForDevice:device];
                                                    }];
}

- (void)dealloc {
    [self removeBatteryStateObserver];
    [self restoreBatteryMonitoringIfNeeded];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self removeBatteryStateObserver];
    [self restoreBatteryMonitoringIfNeeded];
    self.hasKnownExternalPowerState = NO;
    self.externallyPowered = NO;
}

- (void)restoreBatteryMonitoringIfNeeded {
    if (!_enabledBatteryMonitoring) {
        return;
    }
    UIDevice.currentDevice.batteryMonitoringEnabled = NO;
    _enabledBatteryMonitoring = NO;
}

- (void)removeBatteryStateObserver {
    if (!_batteryStateObserver) {
        return;
    }
    [NSNotificationCenter.defaultCenter removeObserver:_batteryStateObserver];
    _batteryStateObserver = nil;
}

#pragma mark - Notifications

- (void)handleBatteryStateDidChangeForDevice:(UIDevice *)device {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    BOOL externallyPowered = NO;
    if (![self readExternalPowerState:&externallyPowered forDevice:device]) {
        HBLogDebug(@"Unable to read power state for power event source");
        return;
    }

    if (!self.hasKnownExternalPowerState) {
        self.hasKnownExternalPowerState = YES;
        self.externallyPowered = externallyPowered;
        return;
    }

    if (self.externallyPowered == externallyPowered) {
        return;
    }

    self.externallyPowered = externallyPowered;
    [self sendPowerEventForExternalPowerState:externallyPowered];
}

- (void)refreshKnownPowerStateWithoutSendingEventForDevice:(UIDevice *)device {
    LAAssertMainQueue();

    BOOL externallyPowered = NO;
    if (![self readExternalPowerState:&externallyPowered forDevice:device]) {
        return;
    }
    self.hasKnownExternalPowerState = YES;
    self.externallyPowered = externallyPowered;
}

#pragma mark - State

- (BOOL)readExternalPowerState:(BOOL *)externallyPowered forDevice:(UIDevice *)device {
    LAAssertMainQueue();

    switch (device.batteryState) {
    case UIDeviceBatteryStateCharging:
    case UIDeviceBatteryStateFull:
        if (externallyPowered) {
            *externallyPowered = YES;
        }
        return YES;
    case UIDeviceBatteryStateUnplugged:
        if (externallyPowered) {
            *externallyPowered = NO;
        }
        return YES;
    case UIDeviceBatteryStateUnknown:
    default:
        return NO;
    }
}

#pragma mark - Event Dispatch

- (void)sendPowerEventForExternalPowerState:(BOOL)externallyPowered {
    LAAssertMainQueue();

    NSString *eventName = externallyPowered ? LAEventNamePowerConnected : LAEventNamePowerDisconnected;
    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
