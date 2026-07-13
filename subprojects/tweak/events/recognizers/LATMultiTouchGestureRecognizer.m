//
//  LATMultiTouchGestureRecognizer.m
//  libactivator
//
//  Created by Lessica on 7/1/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMultiTouchGestureRecognizer.h"

#import <Activator/Activator.h>

#import <math.h>

static CGFloat const LATMultiTouchPinchRatioThreshold = 0.75;
static CGFloat const LATMultiTouchSpreadRatioThreshold = 1.33333337;
static CGFloat const LATMultiTouchTapMovementLimit = 10.0;

typedef NS_ENUM(NSInteger, LATMultiTouchPhase) {
    LATMultiTouchPhaseBegan = 0,
    LATMultiTouchPhaseMoved = 1,
    LATMultiTouchPhaseStationary = 2,
    LATMultiTouchPhaseEnded = 3,
    LATMultiTouchPhaseCancelled = 4,
};

@interface LATMultiTouchGestureRecognizer ()

@property(nonatomic, strong) NSMutableArray<id<NSCopying>> *touchIdentifierOrder;
@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSValue *> *activeTouchLocations;
@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSValue *> *startTouchLocations;
@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSValue *> *finalTouchLocations;
@property(nonatomic, assign) NSUInteger maxTouchCount;
@property(nonatomic, assign) NSUInteger baselineTouchCount;
@property(nonatomic, assign) CGFloat baselineSpanSquaredSum;
@property(nonatomic, assign, getter=hasDispatched) BOOL dispatched;
@property(nonatomic, assign, getter=isTrackingInvalidSession) BOOL trackingInvalidSession;
@property(nonatomic, copy, readwrite, nullable) NSString *recognizedEventName;
@property(nonatomic, assign, readwrite) NSUInteger recognizedTouchCount;

@end

@implementation LATMultiTouchGestureRecognizer

#pragma mark - Lifecycle

- (instancetype)init {
    return [self initWithTarget:nil action:NULL];
}

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget:target action:action];
    if (self) {
        _touchIdentifierOrder = [[NSMutableArray alloc] init];
        _activeTouchLocations = [[NSMutableDictionary alloc] init];
        _startTouchLocations = [[NSMutableDictionary alloc] init];
        _finalTouchLocations = [[NSMutableDictionary alloc] init];
        self.cancelsTouchesInView = NO;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = NO;
    }
    return self;
}

#pragma mark - Recognition

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateWithTouches:touches timestamp:event.timestamp];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateWithTouches:touches timestamp:event.timestamp];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateWithTouches:touches timestamp:event.timestamp];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self updateWithTouches:touches timestamp:event.timestamp];
}

- (void)updateWithTouches:(NSSet<UITouch *> *)touches timestamp:(NSTimeInterval)timestamp {
    if (touches.count == 0) {
        return;
    }

    NSMutableArray<id<NSCopying>> *identifiers = [[NSMutableArray alloc] initWithCapacity:touches.count];
    NSMutableArray<NSNumber *> *phases = [[NSMutableArray alloc] initWithCapacity:touches.count];
    NSMutableArray<NSValue *> *locations = [[NSMutableArray alloc] initWithCapacity:touches.count];
    UIView *view = self.view;
    for (UITouch *touch in touches) {
        [identifiers addObject:[NSValue valueWithNonretainedObject:touch]];
        [phases addObject:@(touch.phase)];
        [locations addObject:[NSValue valueWithCGPoint:[touch locationInView:view]]];
    }

    NSString *eventName = [self updateWithTouchIdentifiers:identifiers
                                                    phases:phases
                                                 locations:locations
                                                    bounds:view.bounds
                                                 timestamp:timestamp];
    [self updateGestureStateWithEventName:eventName];
}

- (nullable NSString *)updateWithTouchIdentifiers:(NSArray<id<NSCopying>> *)identifiers
                                           phases:(NSArray<NSNumber *> *)phases
                                        locations:(NSArray<NSValue *> *)locations
                                           bounds:(CGRect)bounds
                                        timestamp:(__unused NSTimeInterval)timestamp {
    if (CGRectIsEmpty(bounds)) {
        [self clearTrackingState];
        return nil;
    }

    NSMutableArray<id<NSCopying>> *endedTouchIdentifiers = [[NSMutableArray alloc] init];
    BOOL hasCancelledTouch = NO;

    NSUInteger sampleCount = MIN(identifiers.count, MIN(phases.count, locations.count));
    for (NSUInteger index = 0; index < sampleCount; index++) {
        id<NSCopying> identifier = identifiers[index];
        NSNumber *phaseNumber = phases[index];
        NSValue *locationValue = locations[index];
        if (!identifier || !phaseNumber || !locationValue) {
            continue;
        }

        LATMultiTouchPhase phase = (LATMultiTouchPhase)phaseNumber.integerValue;
        switch (phase) {
        case LATMultiTouchPhaseBegan:
        case LATMultiTouchPhaseMoved:
        case LATMultiTouchPhaseStationary:
            [self noteActiveIdentifier:identifier locationValue:locationValue];
            break;
        case LATMultiTouchPhaseEnded:
            [self noteActiveIdentifier:identifier locationValue:locationValue];
            self.finalTouchLocations[identifier] = locationValue;
            [endedTouchIdentifiers addObject:identifier];
            break;
        case LATMultiTouchPhaseCancelled:
            hasCancelledTouch = YES;
            break;
        }
    }

    if (hasCancelledTouch) {
        [self clearTrackingState];
        return nil;
    }

    [self updateBaselineIfNeeded];

    NSString *eventName = nil;
    if (endedTouchIdentifiers.count == 0) {
        eventName = [self pinchOrSpreadEventNameIfReady];
        if (eventName.length > 0) {
            self.recognizedTouchCount = self.activeTouchLocations.count;
        }
    }

    for (id<NSCopying> identifier in endedTouchIdentifiers) {
        [self.activeTouchLocations removeObjectForKey:identifier];
    }

    if (self.activeTouchLocations.count == 0) {
        if (eventName.length == 0) {
            eventName = [self tapEventNameIfReady];
            if (eventName.length > 0) {
                self.recognizedTouchCount = self.maxTouchCount;
            }
        }
        [self clearTrackingState];
    }

    return eventName;
}

- (void)updateGestureStateWithEventName:(nullable NSString *)eventName {
    if (eventName.length > 0) {
        self.recognizedEventName = eventName;
        self.state = UIGestureRecognizerStateRecognized;
        return;
    }

    if (![self hasRecognitionState]) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)noteActiveIdentifier:(id<NSCopying>)identifier locationValue:(NSValue *)locationValue {
    if (!self.startTouchLocations[identifier]) {
        self.startTouchLocations[identifier] = locationValue;
    }
    self.finalTouchLocations[identifier] = locationValue;
    self.activeTouchLocations[identifier] = locationValue;
    if (![self.touchIdentifierOrder containsObject:identifier]) {
        [self.touchIdentifierOrder addObject:identifier];
    }
}

- (void)updateBaselineIfNeeded {
    NSUInteger activeTouchCount = self.activeTouchLocations.count;
    if (activeTouchCount == 0 || self.isTrackingInvalidSession) {
        return;
    }

    if (activeTouchCount > 5) {
        self.trackingInvalidSession = YES;
        return;
    }

    if (activeTouchCount > self.maxTouchCount) {
        self.maxTouchCount = activeTouchCount;
        if ([self supportsTouchCount:activeTouchCount]) {
            self.baselineTouchCount = activeTouchCount;
            self.baselineSpanSquaredSum = [self spanSquaredSumForActiveTouches];
        } else {
            self.baselineTouchCount = 0;
            self.baselineSpanSquaredSum = 0.0;
        }
    }
}

- (nullable NSString *)pinchOrSpreadEventNameIfReady {
    if (self.hasDispatched || self.isTrackingInvalidSession ||
        ![self supportsTouchCount:self.activeTouchLocations.count]) {
        return nil;
    }

    NSUInteger activeTouchCount = self.activeTouchLocations.count;
    if (activeTouchCount != self.maxTouchCount || activeTouchCount != self.baselineTouchCount ||
        self.baselineSpanSquaredSum <= 0.0) {
        return nil;
    }

    CGFloat ratio = [self spanSquaredSumForActiveTouches] / self.baselineSpanSquaredSum;
    NSString *eventName = nil;
    if (ratio < LATMultiTouchPinchRatioThreshold) {
        eventName = [self pinchEventNameForTouchCount:activeTouchCount];
    } else if (ratio > LATMultiTouchSpreadRatioThreshold) {
        eventName = [self spreadEventNameForTouchCount:activeTouchCount];
    }

    if (eventName.length > 0) {
        self.dispatched = YES;
    }
    return eventName;
}

- (nullable NSString *)tapEventNameIfReady {
    if (self.hasDispatched || self.isTrackingInvalidSession || ![self supportsTouchCount:self.maxTouchCount] ||
        self.touchIdentifierOrder.count != self.maxTouchCount) {
        return nil;
    }

    CGFloat movement = 0.0;
    for (id<NSCopying> identifier in self.touchIdentifierOrder) {
        NSValue *startValue = self.startTouchLocations[identifier];
        NSValue *finalValue = self.finalTouchLocations[identifier];
        if (!startValue || !finalValue) {
            return nil;
        }

        CGPoint startLocation = startValue.CGPointValue;
        CGPoint finalLocation = finalValue.CGPointValue;
        CGFloat deltaX = finalLocation.x - startLocation.x;
        CGFloat deltaY = finalLocation.y - startLocation.y;
        movement += (CGFloat)sqrt((double)(deltaX * deltaX + deltaY * deltaY));
    }

    if (movement < LATMultiTouchTapMovementLimit) {
        return [self tapEventNameForTouchCount:self.maxTouchCount];
    }
    return nil;
}

#pragma mark - Geometry

- (CGFloat)spanSquaredSumForActiveTouches {
    NSValue *anchorValue = nil;
    for (id<NSCopying> identifier in self.touchIdentifierOrder) {
        anchorValue = self.activeTouchLocations[identifier];
        if (anchorValue) {
            break;
        }
    }
    if (!anchorValue) {
        return 0.0;
    }

    CGPoint anchorLocation = anchorValue.CGPointValue;
    CGFloat spanSquaredSum = 0.0;
    for (id<NSCopying> identifier in self.touchIdentifierOrder) {
        NSValue *locationValue = self.activeTouchLocations[identifier];
        if (!locationValue) {
            continue;
        }

        CGPoint location = locationValue.CGPointValue;
        CGFloat deltaX = location.x - anchorLocation.x;
        CGFloat deltaY = location.y - anchorLocation.y;
        spanSquaredSum += deltaX * deltaX + deltaY * deltaY;
    }
    return spanSquaredSum;
}

#pragma mark - Event Names

- (BOOL)supportsTouchCount:(NSUInteger)touchCount {
    return touchCount == 3 || touchCount == 4 || touchCount == 5;
}

- (nullable NSString *)tapEventNameForTouchCount:(NSUInteger)touchCount {
    switch (touchCount) {
    case 3:
        return LAEventNameThreeFingerTap;
    case 4:
        return LAEventNameFourFingerTap;
    case 5:
        return LAEventNameFiveFingerTap;
    default:
        return nil;
    }
}

- (nullable NSString *)pinchEventNameForTouchCount:(NSUInteger)touchCount {
    switch (touchCount) {
    case 3:
        return LAEventNameThreeFingerPinch;
    case 4:
        return LAEventNameFourFingerPinch;
    case 5:
        return LAEventNameFiveFingerPinch;
    default:
        return nil;
    }
}

- (nullable NSString *)spreadEventNameForTouchCount:(NSUInteger)touchCount {
    switch (touchCount) {
    case 3:
        return LAEventNameThreeFingerSpread;
    case 4:
        return LAEventNameFourFingerSpread;
    case 5:
        return LAEventNameFiveFingerSpread;
    default:
        return nil;
    }
}

#pragma mark - State

- (void)reset {
    [super reset];
    self.recognizedEventName = nil;
    self.recognizedTouchCount = 0;
    [self clearTrackingState];
}

- (void)clearTrackingState {
    [self.touchIdentifierOrder removeAllObjects];
    [self.activeTouchLocations removeAllObjects];
    [self.startTouchLocations removeAllObjects];
    [self.finalTouchLocations removeAllObjects];
    self.maxTouchCount = 0;
    self.baselineTouchCount = 0;
    self.baselineSpanSquaredSum = 0.0;
    self.dispatched = NO;
    self.trackingInvalidSession = NO;
}

- (BOOL)hasRecognitionState {
    return self.touchIdentifierOrder.count > 0 || self.activeTouchLocations.count > 0 ||
           self.startTouchLocations.count > 0 || self.finalTouchLocations.count > 0 || self.maxTouchCount > 0 ||
           self.baselineTouchCount > 0 || self.baselineSpanSquaredSum > 0.0 || self.hasDispatched ||
           self.isTrackingInvalidSession;
}

- (BOOL)canPreventGestureRecognizer:(__unused UIGestureRecognizer *)preventedGestureRecognizer {
    return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:(__unused UIGestureRecognizer *)preventingGestureRecognizer {
    return NO;
}

#if DEBUG
#pragma mark - Testing Hooks

- (nullable NSString *)la_testingUpdateWithTouchLocations:(NSArray<NSValue *> *)touchLocations
                                                    phase:(UITouchPhase)phase
                                                   bounds:(CGRect)bounds
                                                timestamp:(NSTimeInterval)timestamp {
    NSMutableArray<id<NSCopying>> *identifiers = [[NSMutableArray alloc] initWithCapacity:touchLocations.count];
    NSMutableArray<NSNumber *> *phases = [[NSMutableArray alloc] initWithCapacity:touchLocations.count];
    for (NSUInteger index = 0; index < touchLocations.count; index++) {
        [identifiers addObject:[NSString stringWithFormat:@"touch-%lu", (unsigned long)index]];
        [phases addObject:@(phase)];
    }

    NSString *eventName = [self updateWithTouchIdentifiers:identifiers
                                                    phases:phases
                                                 locations:touchLocations
                                                    bounds:bounds
                                                 timestamp:timestamp];
    if (eventName.length > 0) {
        self.recognizedEventName = eventName;
    }
    return eventName;
}

- (BOOL)la_testingHasRecognitionState {
    return [self hasRecognitionState];
}
#endif

@end
