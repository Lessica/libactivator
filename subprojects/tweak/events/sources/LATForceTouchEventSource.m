//
//  LATForceTouchEventSource.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATForceTouchEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

static NSString *const LATForceTouchSnapshotIdentifierKey = @"Identifier";
static NSString *const LATForceTouchSnapshotForceKey = @"Force";
static NSString *const LATForceTouchSnapshotLocationKey = @"Location";
static NSString *const LATForceTouchSnapshotPhaseKey = @"Phase";

static CGFloat const LATForceTouchStatusBarBand = 38.0;
static CGFloat const LATForceTouchBottomBand = 38.0;
static CGFloat const LATForceTouchSideBand = 14.0;
static CGFloat const LATForceTouchForceThreshold = 5.0;

typedef NS_ENUM(NSInteger, LATForceTouchPhase) {
    LATForceTouchPhaseBegan = 0,
    LATForceTouchPhaseMoved = 1,
    LATForceTouchPhaseStationary = 2,
    LATForceTouchPhaseEnded = 3,
    LATForceTouchPhaseCancelled = 4,
};

@interface LATForceTouchSession : NSObject

@property(nonatomic, copy) NSString *eventName;
@property(nonatomic, assign, getter=hasDispatched) BOOL dispatched;
@property(nonatomic, assign) CGPoint startLocation;

@end

@implementation LATForceTouchSession
@end

@interface LATForceTouchEventSource ()

// Dependencies
@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;

// Lifecycle
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign, getter=isInterested) BOOL interested;

// Recognition state
@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSDictionary<NSString *, id> *> *activeSnapshots;
@property(nonatomic, strong, nullable) LATForceTouchSession *session;
@property(nonatomic, assign, getter=isTrackingUnrecognizedSession) BOOL trackingUnrecognizedSession;

@end

@implementation LATForceTouchEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    if (![context.eventDispatcher hasEventDefinitionWithName:LAEventNameForceTouchScreenBottom]) {
        return nil;
    }
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (NSString *)eventSourceIdentifier {
    return @"force-touch";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameForceTouchStatusBar,
        LAEventNameForceTouchScreenLeft,
        LAEventNameForceTouchScreenRight,
        LAEventNameForceTouchScreenBottomLeft,
        LAEventNameForceTouchScreenBottom,
        LAEventNameForceTouchScreenBottomRight,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAssignedInCurrentMode;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _activeSnapshots = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
        return;
    }
    self.started = YES;
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self resetRecognitionState];
}

- (void)eventSourceInterestDidChange:(BOOL)interested {
    LAAssertMainQueue();
    self.interested = interested;
    if (!interested) {
        [self resetRecognitionState];
    }
}

- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames {
    LAAssertMainQueue();
    self.interested = interestedEventNames.count > 0;
    [self resetRecognitionState];
}

#pragma mark - Touch Entry Points

- (void)noteSystemGestureWindow:(UIWindow *)window event:(UIEvent *)event {
    LAAssertMainQueue();
    if (!self.started || !window || !event) {
        return;
    }

    if (![self shouldProcessEvents]) {
        [self resetRecognitionState];
        return;
    }

    NSArray<NSDictionary<NSString *, id> *> *snapshots = [self touchSnapshotsFromEvent:event inWindow:window];
    if (snapshots.count == 0) {
        return;
    }

    [self handleTouchSnapshots:snapshots bounds:window.bounds timestamp:event.timestamp];
}

#pragma mark - Interest

- (BOOL)shouldProcessEvents {
    LAAssertMainQueue();
    return self.isInterested;
}

#pragma mark - Recognition

- (nullable NSString *)handleTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                     bounds:(CGRect)bounds
                                  timestamp:(__unused NSTimeInterval)timestamp {
    LAAssertMainQueue();
    if (!self.started || snapshots.count == 0 || CGRectIsEmpty(bounds)) {
        return nil;
    }

    NSMutableArray<id<NSCopying>> *endedTouchIdentifiers = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *snapshot in snapshots) {
        id<NSCopying> identifier = snapshot[LATForceTouchSnapshotIdentifierKey];
        NSNumber *phaseNumber = snapshot[LATForceTouchSnapshotPhaseKey];
        if (!identifier || !phaseNumber) {
            continue;
        }

        LATForceTouchPhase phase = (LATForceTouchPhase)phaseNumber.integerValue;
        switch (phase) {
        case LATForceTouchPhaseBegan:
        case LATForceTouchPhaseMoved:
        case LATForceTouchPhaseStationary:
            self.activeSnapshots[identifier] = snapshot;
            break;
        case LATForceTouchPhaseEnded:
        case LATForceTouchPhaseCancelled:
            self.activeSnapshots[identifier] = snapshot;
            [endedTouchIdentifiers addObject:identifier];
            break;
        }
    }

    [self startSessionIfNeededWithBounds:bounds];
    NSString *eventName = [self forceTouchEventNameIfReadyWithBounds:bounds];

    for (id<NSCopying> identifier in endedTouchIdentifiers) {
        [self.activeSnapshots removeObjectForKey:identifier];
    }
    if (self.activeSnapshots.count == 0) {
        [self resetRecognitionState];
    }

    return eventName;
}

- (void)startSessionIfNeededWithBounds:(CGRect)bounds {
    if (self.session || self.isTrackingUnrecognizedSession || self.activeSnapshots.count == 0) {
        return;
    }

    if (self.activeSnapshots.count != 1) {
        self.trackingUnrecognizedSession = YES;
        return;
    }

    NSDictionary<NSString *, id> *snapshot = self.activeSnapshots.allValues.firstObject;
    CGPoint location = [self locationFromSnapshot:snapshot];
    NSString *eventName = [self eventNameForLocation:location bounds:bounds];
    if (eventName.length == 0) {
        self.trackingUnrecognizedSession = YES;
        return;
    }

    LATForceTouchSession *session = [[LATForceTouchSession alloc] init];
    session.eventName = eventName;
    session.startLocation = location;
    self.session = session;
}

- (nullable NSString *)forceTouchEventNameIfReadyWithBounds:(CGRect)bounds {
    LATForceTouchSession *session = self.session;
    if (!session || session.hasDispatched || self.activeSnapshots.count != 1) {
        return nil;
    }

    NSDictionary<NSString *, id> *snapshot = self.activeSnapshots.allValues.firstObject;
    if (![self snapshotCanDispatchForceTouch:snapshot]) {
        return nil;
    }

    CGPoint location = [self locationFromSnapshot:snapshot];
    NSString *currentEventName = [self eventNameForLocation:location bounds:bounds];
    if (![currentEventName isEqualToString:session.eventName]) {
        return nil;
    }

    CGFloat force = [snapshot[LATForceTouchSnapshotForceKey] doubleValue];
    if (force < LATForceTouchForceThreshold) {
        return nil;
    }

    session.dispatched = YES;
    [self sendEventWithName:session.eventName force:force bounds:bounds];
    return session.eventName;
}

- (BOOL)snapshotCanDispatchForceTouch:(NSDictionary<NSString *, id> *)snapshot {
    NSNumber *phaseNumber = snapshot[LATForceTouchSnapshotPhaseKey];
    if (!phaseNumber) {
        return NO;
    }

    LATForceTouchPhase phase = (LATForceTouchPhase)phaseNumber.integerValue;
    return phase == LATForceTouchPhaseBegan || phase == LATForceTouchPhaseMoved ||
           phase == LATForceTouchPhaseStationary;
}

- (void)resetRecognitionState {
    [self.activeSnapshots removeAllObjects];
    self.session = nil;
    self.trackingUnrecognizedSession = NO;
}

#pragma mark - Event Dispatch

- (void)sendEventWithName:(NSString *)eventName force:(CGFloat)force bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (eventName.length == 0) {
        return;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:[self currentEventMode]];
    [self.eventDispatcher dispatchEvent:event];
    HBLogInfo(@"Dispatched force touch event=%@ force=%.3f bounds=%@", eventName, force, NSStringFromCGRect(bounds));
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();

    NSString *eventMode = self.modeProvider.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

#pragma mark - Touch Snapshots

- (NSArray<NSDictionary<NSString *, id> *> *)touchSnapshotsFromEvent:(UIEvent *)event inWindow:(UIWindow *)window {
    NSMutableArray<NSDictionary<NSString *, id> *> *snapshots = [[NSMutableArray alloc] init];
    for (UITouch *touch in event.allTouches) {
        [snapshots addObject:@{
            LATForceTouchSnapshotIdentifierKey : [NSValue valueWithNonretainedObject:touch],
            LATForceTouchSnapshotForceKey : @([touch respondsToSelector:@selector(force)] ? touch.force : 0.0),
            LATForceTouchSnapshotPhaseKey : @(touch.phase),
            LATForceTouchSnapshotLocationKey : [NSValue valueWithCGPoint:[touch locationInView:window]],
        }];
    }
    return snapshots;
}

#pragma mark - Geometry

- (CGPoint)locationFromSnapshot:(NSDictionary<NSString *, id> *)snapshot {
    NSValue *locationValue = snapshot[LATForceTouchSnapshotLocationKey];
    return locationValue ? locationValue.CGPointValue : CGPointZero;
}

- (nullable NSString *)eventNameForLocation:(CGPoint)location bounds:(CGRect)bounds {
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width <= 0.0 || height <= 0.0) {
        return nil;
    }

    if (location.y < LATForceTouchStatusBarBand) {
        return LAEventNameForceTouchStatusBar;
    }

    if (location.y >= height - LATForceTouchBottomBand) {
        if (location.x < width * 0.25) {
            return LAEventNameForceTouchScreenBottomLeft;
        }
        if (location.x < width * 0.75) {
            return LAEventNameForceTouchScreenBottom;
        }
        return LAEventNameForceTouchScreenBottomRight;
    }

    if (location.x < LATForceTouchSideBand) {
        return LAEventNameForceTouchScreenLeft;
    }

    if (location.x > width - LATForceTouchSideBand) {
        return LAEventNameForceTouchScreenRight;
    }

    return nil;
}

#if DEBUG
#pragma mark - Testing Hooks

- (nullable NSString *)la_testingNoteTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                             bounds:(CGRect)bounds
                                          timestamp:(NSTimeInterval)timestamp {
    return [self handleTouchSnapshots:snapshots bounds:bounds timestamp:timestamp];
}

- (nullable NSString *)la_testingEventNameForLocation:(CGPoint)location bounds:(CGRect)bounds {
    return [self eventNameForLocation:location bounds:bounds];
}

- (BOOL)la_testingHasRecognitionState {
    return self.activeSnapshots.count > 0 || self.session != nil || self.isTrackingUnrecognizedSession;
}
#endif

@end
