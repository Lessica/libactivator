//
//  LATPowerStateEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATPowerStateEventSource.h"

#import "LAActivator+Private.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

#define kLATPowerStateEventSourceMainQueueReason @"LATPowerStateEventSource must only be used on the main thread"

@interface LATPowerStateEventSource ()

// Lifecycle
@property(nonatomic, assign) BOOL started;

// External power state
@property(nonatomic, assign) BOOL hasKnownExternalPowerState;
@property(nonatomic, assign, getter=isExternallyPowered) BOOL externallyPowered;

// Observation token
@property(nonatomic, strong, nullable) id<NSObject> batteryStateObserver;

@end

@implementation LATPowerStateEventSource

#pragma mark - Lifecycle

- (void)start {
    NSAssert(NSThread.isMainThread, kLATPowerStateEventSourceMainQueueReason);
    if (self.started) {
        return;
    }
    self.started = YES;

    UIDevice *device = UIDevice.currentDevice;
    if (!device.batteryMonitoringEnabled) {
        device.batteryMonitoringEnabled = YES;
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
    if (_batteryStateObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:_batteryStateObserver];
    }
}

#pragma mark - Notifications

- (void)handleBatteryStateDidChangeForDevice:(UIDevice *)device {
    NSAssert(NSThread.isMainThread, kLATPowerStateEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATPowerStateEventSourceMainQueueReason);

    BOOL externallyPowered = NO;
    if (![self readExternalPowerState:&externallyPowered forDevice:device]) {
        return;
    }
    self.hasKnownExternalPowerState = YES;
    self.externallyPowered = externallyPowered;
}

#pragma mark - State

- (BOOL)readExternalPowerState:(BOOL *)externallyPowered forDevice:(UIDevice *)device {
    NSAssert(NSThread.isMainThread, kLATPowerStateEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATPowerStateEventSourceMainQueueReason);

    NSString *eventName = externallyPowered ? LAEventNamePowerConnected : LAEventNamePowerDisconnected;
    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
