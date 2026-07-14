//
//  LATScheduledEventSource.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATScheduledEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface LATScheduledEventSource ()

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, copy) LATSolarTransitionMonitorFactory monitorFactory;
@property(nonatomic, strong, nullable) id<LATSolarTransitionMonitoring> transitionMonitor;
@property(nonatomic, copy) NSSet<NSString *> *interestedEventNames;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

@end

@implementation LATScheduledEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    if (!LATUIKitSolarTransitionMonitor.isAvailable) {
        return nil;
    }

    return [self initWithEventDispatcher:context.eventDispatcher
                            modeProvider:context.eventDispatcher
                          monitorFactory:^id<LATSolarTransitionMonitoring> {
                              return [[LATUIKitSolarTransitionMonitor alloc] init];
                          }];
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                         monitorFactory:(LATSolarTransitionMonitorFactory)monitorFactory {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);
    NSParameterAssert(monitorFactory);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _monitorFactory = [monitorFactory copy];
        _interestedEventNames = [NSSet set];
    }
    return self;
}

- (NSString *)eventSourceIdentifier {
    return @"scheduled";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithObjects:LAEventNameScheduledSunrise, LAEventNameScheduledSunset, nil];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAssignedInAnyMode;
}

- (void)start {
    LAAssertMainQueue();
    if (self.isStarted || self.isInvalidated) {
        return;
    }

    self.started = YES;
    [self updateMonitoringForInterest];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    self.interestedEventNames = [NSSet set];
    [self.transitionMonitor invalidate];
    self.transitionMonitor = nil;
}

- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames {
    LAAssertMainQueue();
    NSMutableSet<NSString *> *normalizedEventNames = [interestedEventNames mutableCopy];
    [normalizedEventNames intersectSet:self.eventNames];
    self.interestedEventNames = [normalizedEventNames copy];
    [self updateMonitoringForInterest];
}

#pragma mark - Solar Transitions

- (void)updateMonitoringForInterest {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated) {
        return;
    }

    if (self.interestedEventNames.count == 0) {
        [self.transitionMonitor invalidate];
        self.transitionMonitor = nil;
        return;
    }
    if (self.transitionMonitor) {
        return;
    }

    id<LATSolarTransitionMonitoring> transitionMonitor = self.monitorFactory();
    if (!transitionMonitor) {
        HBLogWarn(@"Unable to create scheduled event solar transition monitor");
        return;
    }

    self.transitionMonitor = transitionMonitor;
    __weak typeof(self) weakSelf = self;
    if (![transitionMonitor startWithTransitionHandler:^(BOOL darkScheduleActive) {
            [weakSelf handleDarkScheduleActive:darkScheduleActive];
        }]) {
        HBLogWarn(@"Unable to start scheduled event solar transition monitor");
        [transitionMonitor invalidate];
        self.transitionMonitor = nil;
    }
}

- (void)handleDarkScheduleActive:(BOOL)darkScheduleActive {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated) {
        return;
    }

    NSString *eventName = darkScheduleActive ? LAEventNameScheduledSunset : LAEventNameScheduledSunrise;
    if (![self.interestedEventNames containsObject:eventName]) {
        return;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    [self.eventDispatcher dispatchEvent:[LAEvent eventWithName:eventName mode:eventMode]];
    HBLogInfo(@"Dispatched scheduled solar event name=%@ mode=%@", eventName, eventMode);
}

#if DEBUG
#pragma mark - Testing Hooks

- (BOOL)la_testingHasActiveMonitor {
    return self.transitionMonitor != nil;
}
#endif

@end
