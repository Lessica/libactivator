//
//  LATEdgeGestureEventSource.m
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEdgeGestureEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"
#import "LATEdgeGestureClassifier.h"
#import "LATEventSourceInterestGate.h"
#import "LATFingerprintSensorEventSource.h"

#import <HBLog.h>

@interface LATEdgeGestureEventSource ()

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong) LATEdgeGestureClassifier *classifier;
#if DEBUG
@property(nonatomic, assign) NSTimeInterval lastSideDiagnosticTimestamp;
#endif

@end

@implementation LATEdgeGestureEventSource

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _classifier = [[LATEdgeGestureClassifier alloc] init];
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;
}

#pragma mark - Touch Entry Points

- (void)noteSystemGestureWindow:(UIWindow *)window event:(UIEvent *)event {
    LAAssertMainQueue();
    if (!self.started || !window || !event) {
        return;
    }

    if (![self shouldProcessEvents]) {
        [self.classifier reset];
        return;
    }

    NSArray<NSDictionary<NSString *, id> *> *snapshots = [self touchSnapshotsFromEvent:event inWindow:window];
    if (snapshots.count == 0) {
        return;
    }

#if DEBUG
    [self logSideGestureDiagnosticForTouchSnapshots:snapshots bounds:window.bounds timestamp:event.timestamp];
#endif

    [self handleTouchSnapshots:snapshots bounds:window.bounds timestamp:event.timestamp];
}

#pragma mark - Interest

- (BOOL)shouldProcessEvents {
    LAAssertMainQueue();
    LATEventSourceInterestGate *interestGate = self.interestGate;
    return !interestGate || [interestGate isInterestedInFamily:LATEventSourceInterestFamilyEdgeGesture];
}

#pragma mark - Recognition

- (nullable NSString *)handleTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                     bounds:(CGRect)bounds
                                  timestamp:(NSTimeInterval)timestamp {
    LAAssertMainQueue();
    if (!self.started || snapshots.count == 0) {
        return nil;
    }

    NSString *eventName = [self.classifier updateWithTouchSnapshots:snapshots bounds:bounds timestamp:timestamp];
    if (eventName.length > 0) {
        if ([self shouldRouteEventNameToFingerprintSlideIn:eventName] &&
            [self.fingerprintSensorEventSource consumePendingSinglePressForSlideInAtTimestamp:timestamp]) {
            return LAEventNameFingerprintSensorPressSingleAndSlideIn;
        }
        [self sendEventWithName:eventName touchCount:snapshots.count bounds:bounds];
    }
    return eventName;
}

- (BOOL)shouldRouteEventNameToFingerprintSlideIn:(NSString *)eventName {
    return [eventName isEqualToString:LAEventNameSlideInFromBottom] ||
           [eventName isEqualToString:LAEventNameSlideInFromBottomLeft] ||
           [eventName isEqualToString:LAEventNameSlideInFromBottomRight];
}

#pragma mark - Event Dispatch

- (void)sendEventWithName:(NSString *)eventName touchCount:(NSUInteger)touchCount bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (eventName.length == 0) {
        return;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:[self currentEventMode]];
    [LASharedActivator sendEventToListener:event];
    HBLogInfo(@"Classified and dispatched edge gesture event=%@ touchCount=%lu bounds=%@", eventName,
              (unsigned long)touchCount, NSStringFromCGRect(bounds));
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

#pragma mark - Touch Snapshots

- (NSArray<NSDictionary<NSString *, id> *> *)touchSnapshotsFromEvent:(UIEvent *)event inWindow:(UIWindow *)window {
    NSMutableArray<NSDictionary<NSString *, id> *> *snapshots = [[NSMutableArray alloc] init];
    for (UITouch *touch in event.allTouches) {
        CGPoint location = [touch locationInView:window];
        [snapshots addObject:@{
            LATEdgeGestureTouchIdentifierKey : [NSValue valueWithNonretainedObject:touch],
            LATEdgeGestureTouchPhaseKey : @(touch.phase),
            LATEdgeGestureTouchLocationKey : [NSValue valueWithCGPoint:location],
        }];
    }
    return snapshots;
}

#if DEBUG
#pragma mark - Debug Diagnostics

- (void)logSideGestureDiagnosticForTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                           bounds:(CGRect)bounds
                                        timestamp:(NSTimeInterval)timestamp {
    if (CGRectIsEmpty(bounds) || timestamp - self.lastSideDiagnosticTimestamp < 0.03) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat sideDiagnosticBand = MIN(MAX(width * 0.15, 80.0), 140.0);
    NSUInteger activeTouchCount = 0;
    CGFloat minX = CGFLOAT_MAX;
    CGFloat maxX = -CGFLOAT_MAX;
    CGFloat xTotal = 0.0;
    CGFloat yTotal = 0.0;
    NSMutableArray<NSString *> *touchDescriptions = [[NSMutableArray alloc] init];

    for (NSDictionary<NSString *, id> *snapshot in snapshots) {
        NSNumber *phaseNumber = snapshot[LATEdgeGestureTouchPhaseKey];
        NSValue *locationValue = snapshot[LATEdgeGestureTouchLocationKey];
        if (!phaseNumber || !locationValue) {
            continue;
        }

        NSInteger phase = phaseNumber.integerValue;
        CGPoint location = locationValue.CGPointValue;
        [touchDescriptions
            addObject:[NSString stringWithFormat:@"phase=%ld location=%@", (long)phase, NSStringFromCGPoint(location)]];
        if (phase == 3 || phase == 4) {
            continue;
        }

        activeTouchCount++;
        minX = MIN(minX, location.x);
        maxX = MAX(maxX, location.x);
        xTotal += location.x;
        yTotal += location.y;
    }

    if (activeTouchCount == 0) {
        return;
    }

    BOOL nearLeftSide = minX <= sideDiagnosticBand;
    BOOL nearRightSide = maxX >= width - sideDiagnosticBand;
    if (!nearLeftSide && !nearRightSide) {
        return;
    }

    self.lastSideDiagnosticTimestamp = timestamp;
    CGPoint centroid = CGPointMake(xTotal / (CGFloat)activeTouchCount, yTotal / (CGFloat)activeTouchCount);
    HBLogInfo(@"Edge gesture diagnostic activeTouchCount=%lu totalTouchCount=%lu minX=%.1f maxX=%.1f centroid=%@ "
              @"bounds=%@ touches=[%@]",
              (unsigned long)activeTouchCount, (unsigned long)snapshots.count, minX, maxX,
              NSStringFromCGPoint(centroid), NSStringFromCGRect(bounds),
              [touchDescriptions componentsJoinedByString:@"; "]);
}

#pragma mark - Testing Hooks

- (nullable NSString *)la_testingNoteTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                             bounds:(CGRect)bounds
                                          timestamp:(NSTimeInterval)timestamp {
    return [self handleTouchSnapshots:snapshots bounds:bounds timestamp:timestamp];
}
#endif

@end
