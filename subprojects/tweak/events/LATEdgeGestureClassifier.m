//
//  LATEdgeGestureClassifier.m
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEdgeGestureClassifier.h"

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>
#import <math.h>

NSString *const LATEdgeGestureTouchIdentifierKey = @"Identifier";
NSString *const LATEdgeGestureTouchPhaseKey = @"Phase";
NSString *const LATEdgeGestureTouchLocationKey = @"Location";

static CGFloat const LATEdgeGestureClassifierTopBottomStartBand = 13.0;
static CGFloat const LATEdgeGestureClassifierSingleFingerSideStartBand = 13.0;
static CGFloat const LATEdgeGestureClassifierTwoFingerSideStartBand = 26.0;
static CGFloat const LATEdgeGestureClassifierTriggerInset = 63.0;
static CGFloat const LATEdgeGestureClassifierDragAlongEdgeBand = 13.0;
static CGFloat const LATEdgeGestureClassifierDragAlongBottomFudge = 2.0;
static CGFloat const LATEdgeGestureClassifierDragAlongTriggerDistance = 30.0;
static CGFloat const LATEdgeGestureClassifierDragAlongPerpendicularTolerance = 5.0;
static CGFloat const LATEdgeGestureClassifierDragOffStartInset = 25.0;
static CGFloat const LATEdgeGestureClassifierDragOffTriggerInset = 20.0;
static CGFloat const LATEdgeGestureClassifierDragOffCornerInset = 50.0;

typedef NS_ENUM(NSInteger, LATEdgeGestureTouchPhase) {
    LATEdgeGestureTouchPhaseBegan = 0,
    LATEdgeGestureTouchPhaseMoved = 1,
    LATEdgeGestureTouchPhaseStationary = 2,
    LATEdgeGestureTouchPhaseEnded = 3,
    LATEdgeGestureTouchPhaseCancelled = 4,
};

typedef NS_ENUM(NSInteger, LATEdgeGestureDragAxis) {
    LATEdgeGestureDragAxisHorizontal = 0,
    LATEdgeGestureDragAxisVertical = 1,
};

@interface LATEdgeGestureDragCandidate : NSObject

@property(nonatomic, assign) LATEdgeGestureDragAxis axis;
@property(nonatomic, copy) NSString *negativeEventName;
@property(nonatomic, copy) NSString *positiveEventName;

@end

@implementation LATEdgeGestureDragCandidate
@end

@interface LATEdgeGestureSession : NSObject

@property(nonatomic, assign) CGPoint startCentroid;
@property(nonatomic, assign) CGRect bounds;
@property(nonatomic, assign) CGRect triggerRect;
@property(nonatomic, copy) NSString *singleFingerEventName;
@property(nonatomic, copy) NSString *twoFingerEventName;
@property(nonatomic, copy) NSArray<LATEdgeGestureDragCandidate *> *dragCandidates;
@property(nonatomic, assign, getter=isDragOffEligible) BOOL dragOffEligible;
@property(nonatomic, assign, getter=hasClassified) BOOL classified;

@end

@implementation LATEdgeGestureSession
@end

@interface LATEdgeGestureClassifier ()

@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSValue *> *activeTouchLocations;
@property(nonatomic, strong) NSMutableSet<id<NSCopying>> *endedTouchIdentifiers;
@property(nonatomic, strong) NSMutableSet<id<NSCopying>> *finishedTouchIdentifiers;
@property(nonatomic, strong, nullable) LATEdgeGestureSession *session;
@property(nonatomic, assign, getter=isTrackingUnrecognizedSession) BOOL trackingUnrecognizedSession;

@end

@implementation LATEdgeGestureClassifier

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTouchLocations = [[NSMutableDictionary alloc] init];
        _endedTouchIdentifiers = [[NSMutableSet alloc] init];
        _finishedTouchIdentifiers = [[NSMutableSet alloc] init];
    }
    return self;
}

#pragma mark - Recognition

- (nullable NSString *)updateWithTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)touchSnapshots
                                         bounds:(CGRect)bounds
                                      timestamp:(__unused NSTimeInterval)timestamp {
    if (CGRectIsEmpty(bounds)) {
        [self reset];
        return nil;
    }

    NSMutableArray<id<NSCopying>> *endedTouchIdentifiers = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *snapshot in touchSnapshots) {
        id<NSCopying> identifier = snapshot[LATEdgeGestureTouchIdentifierKey];
        NSNumber *phaseNumber = snapshot[LATEdgeGestureTouchPhaseKey];
        NSValue *locationValue = snapshot[LATEdgeGestureTouchLocationKey];
        if (!identifier || !phaseNumber || !locationValue) {
            continue;
        }

        LATEdgeGestureTouchPhase phase = (LATEdgeGestureTouchPhase)phaseNumber.integerValue;
        switch (phase) {
        case LATEdgeGestureTouchPhaseBegan:
        case LATEdgeGestureTouchPhaseMoved:
        case LATEdgeGestureTouchPhaseStationary:
            self.activeTouchLocations[identifier] = locationValue;
            [self.endedTouchIdentifiers removeObject:identifier];
            [self.finishedTouchIdentifiers removeObject:identifier];
            break;
        case LATEdgeGestureTouchPhaseEnded:
            self.activeTouchLocations[identifier] = locationValue;
            [endedTouchIdentifiers addObject:identifier];
            [self.endedTouchIdentifiers addObject:identifier];
            [self.finishedTouchIdentifiers addObject:identifier];
            break;
        case LATEdgeGestureTouchPhaseCancelled:
            self.activeTouchLocations[identifier] = locationValue;
            [endedTouchIdentifiers addObject:identifier];
            [self.finishedTouchIdentifiers addObject:identifier];
            break;
        }
    }

    [self startSessionIfNeededWithBounds:bounds];
    NSString *classifiedEventName = [self classifiedEventNameIfReady];

    for (id<NSCopying> identifier in endedTouchIdentifiers) {
        [self.activeTouchLocations removeObjectForKey:identifier];
    }
    if (self.activeTouchLocations.count == 0) {
        [self reset];
    }

    return classifiedEventName;
}

- (void)startSessionIfNeededWithBounds:(CGRect)bounds {
    if (self.session || self.isTrackingUnrecognizedSession || self.activeTouchLocations.count == 0) {
        return;
    }

    if (self.activeTouchLocations.count > 2) {
        self.trackingUnrecognizedSession = YES;
        return;
    }

    CGPoint centroid = [self centroidForActiveTouches];
    self.session = [self sessionForStartCentroid:centroid bounds:bounds];
    if (!self.session) {
        self.trackingUnrecognizedSession = YES;
    }
}

- (nullable NSString *)classifiedEventNameIfReady {
    LATEdgeGestureSession *session = self.session;
    if (!session || session.hasClassified || self.activeTouchLocations.count == 0) {
        return nil;
    }

    CGPoint centroid = [self centroidForActiveTouches];
    if ([self triggerRect:session.triggerRect containsPointInclusively:centroid]) {
        NSString *slideInEventName = nil;
        if (self.activeTouchLocations.count == 2) {
            slideInEventName = session.twoFingerEventName;
        } else if (self.activeTouchLocations.count == 1) {
            slideInEventName = session.singleFingerEventName;
        }
        if (slideInEventName.length > 0) {
            session.classified = YES;
            return slideInEventName;
        }
    }

    NSString *eventName = [self dragAlongEventNameForSession:session centroid:centroid];
    if (eventName.length == 0) {
        eventName = [self dragOffEventNameForSession:session centroid:centroid];
    }
    session.classified = eventName.length > 0;
    return eventName;
}

- (nullable NSString *)dragAlongEventNameForSession:(LATEdgeGestureSession *)session centroid:(CGPoint)centroid {
    if (self.activeTouchLocations.count != 1 || self.finishedTouchIdentifiers.count > 0) {
        return nil;
    }

    for (LATEdgeGestureDragCandidate *candidate in session.dragCandidates) {
        CGFloat delta = candidate.axis == LATEdgeGestureDragAxisHorizontal ? centroid.x - session.startCentroid.x
                                                                           : centroid.y - session.startCentroid.y;
        CGFloat perpendicularDelta = candidate.axis == LATEdgeGestureDragAxisHorizontal ? centroid.y - session.startCentroid.y
                                                                                       : centroid.x - session.startCentroid.x;
        if (fabs(perpendicularDelta) >= LATEdgeGestureClassifierDragAlongPerpendicularTolerance) {
            continue;
        }

        if (delta > LATEdgeGestureClassifierDragAlongTriggerDistance) {
            return candidate.positiveEventName;
        }
        if (delta < -LATEdgeGestureClassifierDragAlongTriggerDistance) {
            return candidate.negativeEventName;
        }
    }

    return nil;
}

- (nullable NSString *)dragOffEventNameForSession:(LATEdgeGestureSession *)session centroid:(CGPoint)centroid {
    if (!session.isDragOffEligible || self.activeTouchLocations.count != 1 ||
        self.endedTouchIdentifiers.count != 1 || self.finishedTouchIdentifiers.count != 1) {
        return nil;
    }

    CGFloat width = CGRectGetWidth(session.bounds);
    CGFloat height = CGRectGetHeight(session.bounds);
    if (width <= 0.0 || height <= 0.0) {
        return nil;
    }

    BOOL yAwayFromCorners = centroid.y > LATEdgeGestureClassifierDragOffTriggerInset &&
                            centroid.y < height - LATEdgeGestureClassifierDragOffCornerInset;
    BOOL xAwayFromCorners = centroid.x > LATEdgeGestureClassifierDragOffTriggerInset &&
                            centroid.x < width - LATEdgeGestureClassifierDragOffCornerInset;
    if (centroid.x < LATEdgeGestureClassifierDragOffTriggerInset && yAwayFromCorners) {
        return LAEventNameDragOffLeft;
    }
    if (centroid.x > width - LATEdgeGestureClassifierDragOffTriggerInset && yAwayFromCorners) {
        return LAEventNameDragOffRight;
    }
    if (centroid.y < LATEdgeGestureClassifierDragOffTriggerInset && xAwayFromCorners) {
        return LAEventNameDragOffTop;
    }
    if (centroid.y > height - LATEdgeGestureClassifierDragOffTriggerInset && xAwayFromCorners) {
        return LAEventNameDragOffBottom;
    }

    return nil;
}

#pragma mark - State

- (void)reset {
    [self.activeTouchLocations removeAllObjects];
    [self.endedTouchIdentifiers removeAllObjects];
    [self.finishedTouchIdentifiers removeAllObjects];
    self.session = nil;
    self.trackingUnrecognizedSession = NO;
}

#pragma mark - Geometry

- (CGPoint)centroidForActiveTouches {
    CGFloat x = 0.0;
    CGFloat y = 0.0;
    for (NSValue *value in self.activeTouchLocations.objectEnumerator) {
        CGPoint point = value.CGPointValue;
        x += point.x;
        y += point.y;
    }

    NSUInteger count = self.activeTouchLocations.count;
    if (count == 0) {
        return CGPointZero;
    }
    return CGPointMake(x / (CGFloat)count, y / (CGFloat)count);
}

- (BOOL)triggerRect:(CGRect)triggerRect containsPointInclusively:(CGPoint)point {
    if (CGRectIsNull(triggerRect) || CGRectIsEmpty(triggerRect)) {
        return NO;
    }

    return point.x >= CGRectGetMinX(triggerRect) && point.x <= CGRectGetMaxX(triggerRect) &&
           point.y >= CGRectGetMinY(triggerRect) && point.y <= CGRectGetMaxY(triggerRect);
}

#pragma mark - Session Configuration

- (nullable LATEdgeGestureSession *)sessionForStartCentroid:(CGPoint)centroid bounds:(CGRect)bounds {
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width <= 0.0 || height <= 0.0) {
        return nil;
    }

    LATEdgeGestureSession *session = [[LATEdgeGestureSession alloc] init];
    session.startCentroid = centroid;
    session.bounds = bounds;
    NSMutableArray<LATEdgeGestureDragCandidate *> *dragCandidates = [[NSMutableArray alloc] init];
    CGFloat sideStartBand = self.activeTouchLocations.count == 2 ? LATEdgeGestureClassifierTwoFingerSideStartBand
                                                                 : LATEdgeGestureClassifierSingleFingerSideStartBand;

    if (centroid.y + LATEdgeGestureClassifierTopBottomStartBand >= height) {
        [self configureBottomSession:session
                             centroid:centroid
                                width:width
                               height:height
                         triggerInset:LATEdgeGestureClassifierTriggerInset];
    } else if (centroid.y < LATEdgeGestureClassifierTopBottomStartBand) {
        [self configureTopSession:session
                          centroid:centroid
                             width:width
                            height:height
                      triggerInset:LATEdgeGestureClassifierTriggerInset];
    } else if (centroid.x < sideStartBand) {
        [self configureLeftSession:session
                           centroid:centroid
                              width:width
                             height:height
                       triggerInset:LATEdgeGestureClassifierTriggerInset];
    } else if (centroid.x >= width - sideStartBand) {
        [self configureRightSession:session
                            centroid:centroid
                               width:width
                              height:height
                        triggerInset:LATEdgeGestureClassifierTriggerInset];
    } else {
        session.triggerRect = CGRectNull;
    }

    if (self.activeTouchLocations.count == 1) {
        [self appendDragAlongCandidatesToArray:dragCandidates centroid:centroid width:width height:height];
        session.dragOffEligible = [self dragOffEligibleForStartCentroid:centroid width:width height:height];
    }
    session.dragCandidates = dragCandidates;

    BOOL hasSlideInGesture = session.singleFingerEventName.length > 0 && session.twoFingerEventName.length > 0 &&
                             !CGRectIsNull(session.triggerRect);
    BOOL hasDragAlongGesture = session.dragCandidates.count > 0;
    BOOL hasDragOffGesture = session.isDragOffEligible;
    return hasSlideInGesture || hasDragAlongGesture || hasDragOffGesture ? session : nil;
}

- (void)configureBottomSession:(LATEdgeGestureSession *)session
                      centroid:(CGPoint)centroid
                         width:(CGFloat)width
                        height:(CGFloat)height
                  triggerInset:(CGFloat)triggerInset {
    if (centroid.x < width * 0.25) {
        session.singleFingerEventName = LAEventNameSlideInFromBottomLeft;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromBottomLeft;
    } else if (centroid.x < width * 0.75) {
        session.singleFingerEventName = LAEventNameSlideInFromBottom;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromBottom;
    } else {
        session.singleFingerEventName = LAEventNameSlideInFromBottomRight;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromBottomRight;
    }
    session.triggerRect = CGRectMake(0.0, 0.0, width, MAX(0.0, height - triggerInset));
}

- (void)configureTopSession:(LATEdgeGestureSession *)session
                   centroid:(CGPoint)centroid
                      width:(CGFloat)width
                     height:(CGFloat)height
               triggerInset:(CGFloat)triggerInset {
    if (centroid.x < width * 0.25) {
        session.singleFingerEventName = LAEventNameSlideInFromTopLeft;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromTopLeft;
    } else if (centroid.x < width * 0.75) {
        session.singleFingerEventName = LAEventNameStatusBarSwipeDown;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromTop;
    } else {
        session.singleFingerEventName = LAEventNameSlideInFromTopRight;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromTopRight;
    }
    session.triggerRect = CGRectMake(0.0, MIN(triggerInset, height), width, MAX(0.0, height - triggerInset));
}

- (void)configureLeftSession:(LATEdgeGestureSession *)session
                    centroid:(CGPoint)centroid
                       width:(CGFloat)width
                      height:(CGFloat)height
                triggerInset:(CGFloat)triggerInset {
    if (centroid.y < height * 0.25) {
        session.singleFingerEventName = LAEventNameSlideInFromLeftTop;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromLeftTop;
    } else if (centroid.y < height * 0.75) {
        session.singleFingerEventName = LAEventNameSlideInFromLeft;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromLeft;
    } else {
        session.singleFingerEventName = LAEventNameSlideInFromLeftBottom;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromLeftBottom;
    }
    session.triggerRect = CGRectMake(MIN(triggerInset, width), 0.0, MAX(0.0, width - triggerInset), height);
}

- (void)configureRightSession:(LATEdgeGestureSession *)session
                     centroid:(CGPoint)centroid
                        width:(CGFloat)width
                       height:(CGFloat)height
                 triggerInset:(CGFloat)triggerInset {
    if (centroid.y < height * 0.25) {
        session.singleFingerEventName = LAEventNameSlideInFromRightTop;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromRightTop;
    } else if (centroid.y < height * 0.75) {
        session.singleFingerEventName = LAEventNameSlideInFromRight;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromRight;
    } else {
        session.singleFingerEventName = LAEventNameSlideInFromRightBottom;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromRightBottom;
    }
    session.triggerRect = CGRectMake(0.0, 0.0, MAX(0.0, width - triggerInset), height);
}

- (void)appendDragAlongCandidatesToArray:(NSMutableArray<LATEdgeGestureDragCandidate *> *)dragCandidates
                                centroid:(CGPoint)centroid
                                   width:(CGFloat)width
                                  height:(CGFloat)height {
    CGFloat edgeBand = LATEdgeGestureClassifierDragAlongEdgeBand;
    if (centroid.y + LATEdgeGestureClassifierDragAlongBottomFudge + edgeBand >= height) {
        LATEdgeGestureDragCandidate *bottomCandidate = [[LATEdgeGestureDragCandidate alloc] init];
        bottomCandidate.axis = LATEdgeGestureDragAxisHorizontal;
        bottomCandidate.negativeEventName = LAEventScreenBottomSwipeLeft;
        bottomCandidate.positiveEventName = LAEventScreenBottomSwipeRight;
        [dragCandidates addObject:bottomCandidate];
    }

    if (centroid.x < edgeBand) {
        LATEdgeGestureDragCandidate *leftCandidate = [[LATEdgeGestureDragCandidate alloc] init];
        leftCandidate.axis = LATEdgeGestureDragAxisVertical;
        leftCandidate.negativeEventName = LAEventScreenLeftSwipeUp;
        leftCandidate.positiveEventName = LAEventScreenLeftSwipeDown;
        [dragCandidates addObject:leftCandidate];
    }

    if (centroid.x >= width - edgeBand) {
        LATEdgeGestureDragCandidate *rightCandidate = [[LATEdgeGestureDragCandidate alloc] init];
        rightCandidate.axis = LATEdgeGestureDragAxisVertical;
        rightCandidate.negativeEventName = LAEventScreenRightSwipeUp;
        rightCandidate.positiveEventName = LAEventScreenRightSwipeDown;
        [dragCandidates addObject:rightCandidate];
    }
}

- (BOOL)dragOffEligibleForStartCentroid:(CGPoint)centroid width:(CGFloat)width height:(CGFloat)height {
    CGRect startRect = CGRectMake(LATEdgeGestureClassifierDragOffStartInset,
                                  LATEdgeGestureClassifierDragOffStartInset,
                                  MAX(0.0, width - LATEdgeGestureClassifierDragOffStartInset * 2.0),
                                  MAX(0.0, height - LATEdgeGestureClassifierDragOffStartInset * 2.0));
    return [self triggerRect:startRect containsPointInclusively:centroid];
}

@end
