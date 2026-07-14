//
//  LATestScheduledEventSourceSuite.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestScheduledEventSourceSuite.h"

#import "LATScheduledEventSource.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@interface LATestSolarTransitionMonitor : NSObject <LATSolarTransitionMonitoring>

@property(nonatomic, assign, getter=isDarkScheduleActive) BOOL darkScheduleActive;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign) NSUInteger invalidateCount;
@property(nonatomic, copy, nullable) LATSolarTransitionHandler transitionHandler;

- (instancetype)initWithDarkScheduleActive:(BOOL)darkScheduleActive;
- (void)transitionToDarkScheduleActive:(BOOL)darkScheduleActive;

@end

@implementation LATestSolarTransitionMonitor

- (instancetype)initWithDarkScheduleActive:(BOOL)darkScheduleActive {
    self = [super init];
    if (self) {
        _darkScheduleActive = darkScheduleActive;
    }
    return self;
}

- (BOOL)startWithTransitionHandler:(LATSolarTransitionHandler)transitionHandler {
    if (self.isInvalidated) {
        return NO;
    }

    self.started = YES;
    self.transitionHandler = transitionHandler;
    return YES;
}

- (void)invalidate {
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    self.invalidateCount += 1;
    self.transitionHandler = nil;
}

- (void)transitionToDarkScheduleActive:(BOOL)darkScheduleActive {
    if (!self.isStarted || self.isInvalidated || darkScheduleActive == self.isDarkScheduleActive) {
        return;
    }

    self.darkScheduleActive = darkScheduleActive;
    self.transitionHandler(darkScheduleActive);
}

@end

@interface LATestScheduledEventRuntime : NSObject <LATEventDispatching, LATEventModeProviding>

@property(nonatomic, copy) NSString *currentEventMode;
@property(nonatomic, copy) NSString *currentEventModeUnderneathLockScreen;
@property(nonatomic, strong) NSMutableArray<LAEvent *> *dispatchedEvents;

- (NSUInteger)dispatchCountForEventName:(NSString *)eventName;

@end

@implementation LATestScheduledEventRuntime

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentEventMode = LAEventModeSpringBoard;
        _currentEventModeUnderneathLockScreen = LAEventModeSpringBoard;
        _dispatchedEvents = [NSMutableArray array];
    }
    return self;
}

- (void)dispatchEvent:(LAEvent *)event {
    [self.dispatchedEvents addObject:event];
}

- (void)abortEvent:(__unused LAEvent *)event {
}

- (void)deactivateEvent:(__unused LAEvent *)event {
}

- (NSUInteger)dispatchCountForEventName:(NSString *)eventName {
    NSUInteger count = 0;
    for (LAEvent *event in self.dispatchedEvents) {
        if ([event.name isEqualToString:eventName]) {
            count += 1;
        }
    }
    return count;
}

@end

@implementation LATestScheduledEventSourceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"ScheduledEventSource"];

    LATUIKitSolarTransitionMonitor *uiKitMonitor = [[LATUIKitSolarTransitionMonitor alloc] init];
    __block NSUInteger uiKitTransitionCount = 0;
    BOOL startedUIKitMonitor = [uiKitMonitor startWithTransitionHandler:^(__unused BOOL darkScheduleActive) {
        uiKitTransitionCount += 1;
    }];
    BOOL restartedUIKitMonitor = [uiKitMonitor startWithTransitionHandler:^(__unused BOOL darkScheduleActive) {
        uiKitTransitionCount += 1;
    }];
    [uiKitMonitor invalidate];
    [uiKitMonitor invalidate];
    [recorder expect:startedUIKitMonitor && restartedUIKitMonitor && uiKitTransitionCount == 0
            caseName:@"scheduled-source-real-uikit-monitor-lifecycle"
              reason:@"UIKit solar monitor did not start idempotently or emitted a transition during lifecycle setup"];

    LATestScheduledEventRuntime *runtime = [[LATestScheduledEventRuntime alloc] init];
    runtime.currentEventMode = LAEventModeApplication;
    runtime.currentEventModeUnderneathLockScreen = LAEventModeApplication;
    __block NSMutableArray<LATestSolarTransitionMonitor *> *monitors = [NSMutableArray array];
    LATScheduledEventSource *source = [[LATScheduledEventSource alloc]
        initWithEventDispatcher:runtime
                   modeProvider:runtime
                 monitorFactory:^id<LATSolarTransitionMonitoring> {
                     LATestSolarTransitionMonitor *monitor =
                         [[LATestSolarTransitionMonitor alloc] initWithDarkScheduleActive:NO];
                     [monitors addObject:monitor];
                     return monitor;
                 }];

    [source eventSourceInterestedEventNamesDidChange:[NSSet setWithObject:LAEventNameScheduledSunrise]];
    [recorder expect:monitors.count == 0
            caseName:@"scheduled-source-defers-monitor-until-start"
              reason:@"Scheduled source created its solar monitor before startup"];

    [source start];
    [source start];
    LATestSolarTransitionMonitor *firstMonitor = monitors.lastObject;
    [recorder expect:monitors.count == 1 && firstMonitor.isStarted && !firstMonitor.isInvalidated
            caseName:@"scheduled-source-starts-one-monitor-for-interest"
              reason:@"Scheduled source did not start exactly one solar monitor for assigned events"];

    [firstMonitor transitionToDarkScheduleActive:YES];
    [firstMonitor transitionToDarkScheduleActive:NO];
    LAEvent *sunriseEvent = runtime.dispatchedEvents.lastObject;
    [recorder expect:[runtime dispatchCountForEventName:LAEventNameScheduledSunrise] == 1 &&
                     [runtime dispatchCountForEventName:LAEventNameScheduledSunset] == 0 &&
                     [sunriseEvent.mode isEqualToString:LAEventModeApplication]
            caseName:@"scheduled-source-dispatches-interested-sunrise-in-current-mode"
              reason:@"Scheduled source did not filter the sunset transition or dispatch sunrise in the current mode"];

    [source eventSourceInterestedEventNamesDidChange:[NSSet setWithObjects:LAEventNameScheduledSunrise,
                                                                           LAEventNameScheduledSunset, nil]];
    [firstMonitor transitionToDarkScheduleActive:YES];
    [firstMonitor transitionToDarkScheduleActive:YES];
    [recorder
          expect:monitors.count == 1 && [runtime dispatchCountForEventName:LAEventNameScheduledSunset] == 1
        caseName:@"scheduled-source-reuses-monitor-and-deduplicates-transition"
          reason:@"Scheduled source replaced its monitor for an interest-set change or duplicated a solar transition"];

    [source eventSourceInterestedEventNamesDidChange:[NSSet set]];
    [firstMonitor transitionToDarkScheduleActive:NO];
    [recorder
          expect:firstMonitor.isInvalidated && firstMonitor.invalidateCount == 1 && runtime.dispatchedEvents.count == 2
        caseName:@"scheduled-source-removes-monitor-after-interest-loss"
          reason:@"Scheduled source retained monitoring or dispatched after its final assignment disappeared"];

    [source eventSourceInterestedEventNamesDidChange:[NSSet setWithObject:LAEventNameScheduledSunset]];
    LATestSolarTransitionMonitor *secondMonitor = monitors.lastObject;
    [secondMonitor transitionToDarkScheduleActive:YES];
    [recorder expect:monitors.count == 2 && secondMonitor != firstMonitor && secondMonitor.isStarted &&
                     [runtime dispatchCountForEventName:LAEventNameScheduledSunset] == 2
            caseName:@"scheduled-source-restores-monitor-after-interest-returns"
              reason:@"Scheduled source did not create a fresh monitor when assignment interest returned"];

    [source invalidate];
    [source invalidate];
    [secondMonitor transitionToDarkScheduleActive:NO];
    [recorder expect:secondMonitor.isInvalidated && secondMonitor.invalidateCount == 1 &&
                     runtime.dispatchedEvents.count == 3
            caseName:@"scheduled-source-invalidate-is-terminal"
              reason:@"Scheduled source did not tear down monitoring exactly once during invalidation"];
}

@end
