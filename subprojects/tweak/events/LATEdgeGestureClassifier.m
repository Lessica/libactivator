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

NSString *const LATEdgeGestureTouchIdentifierKey = @"Identifier";
NSString *const LATEdgeGestureTouchPhaseKey = @"Phase";
NSString *const LATEdgeGestureTouchLocationKey = @"Location";

static CGFloat const LATEdgeGestureClassifierTopBottomStartBand = 13.0;
static CGFloat const LATEdgeGestureClassifierSingleFingerSideStartBand = 18.0;
static CGFloat const LATEdgeGestureClassifierTwoFingerSideStartBand = 56.0;
static CGFloat const LATEdgeGestureClassifierTriggerInset = 63.0;

typedef NS_ENUM(NSInteger, LATEdgeGestureTouchPhase) {
    LATEdgeGestureTouchPhaseBegan = 0,
    LATEdgeGestureTouchPhaseMoved = 1,
    LATEdgeGestureTouchPhaseStationary = 2,
    LATEdgeGestureTouchPhaseEnded = 3,
    LATEdgeGestureTouchPhaseCancelled = 4,
};

@interface LATEdgeGestureSession : NSObject

@property(nonatomic, assign) CGPoint startCentroid;
@property(nonatomic, assign) CGRect triggerRect;
@property(nonatomic, copy) NSString *singleFingerEventName;
@property(nonatomic, copy) NSString *twoFingerEventName;
@property(nonatomic, assign, getter=hasClassified) BOOL classified;

@end

@implementation LATEdgeGestureSession
@end

@interface LATEdgeGestureClassifier ()

@property(nonatomic, strong) NSMutableDictionary<id<NSCopying>, NSValue *> *activeTouchLocations;
@property(nonatomic, strong, nullable) LATEdgeGestureSession *session;
@property(nonatomic, assign, getter=isTrackingUnrecognizedSession) BOOL trackingUnrecognizedSession;

@end

@implementation LATEdgeGestureClassifier

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeTouchLocations = [[NSMutableDictionary alloc] init];
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
            break;
        case LATEdgeGestureTouchPhaseEnded:
        case LATEdgeGestureTouchPhaseCancelled:
            self.activeTouchLocations[identifier] = locationValue;
            [endedTouchIdentifiers addObject:identifier];
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
    if (![self triggerRect:session.triggerRect containsPointInclusively:centroid]) {
        return nil;
    }

    NSString *eventName = nil;
    if (self.activeTouchLocations.count == 2) {
        eventName = session.twoFingerEventName;
    } else if (self.activeTouchLocations.count == 1) {
        eventName = session.singleFingerEventName;
    }
    session.classified = eventName.length > 0;
    return eventName;
}

#pragma mark - State

- (void)reset {
    [self.activeTouchLocations removeAllObjects];
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
        return nil;
    }

    return session.singleFingerEventName.length > 0 && session.twoFingerEventName.length > 0 ? session : nil;
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
        session.singleFingerEventName = @"libactivator.slide-in.left-top";
        session.twoFingerEventName = @"libactivator.two-finger-slide-in.left-top";
    } else if (centroid.y < height * 0.75) {
        session.singleFingerEventName = LAEventNameSlideInFromLeft;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromLeft;
    } else {
        session.singleFingerEventName = @"libactivator.slide-in.left-bottom";
        session.twoFingerEventName = @"libactivator.two-finger-slide-in.left-bottom";
    }
    session.triggerRect = CGRectMake(MIN(triggerInset, width), 0.0, MAX(0.0, width - triggerInset), height);
}

- (void)configureRightSession:(LATEdgeGestureSession *)session
                     centroid:(CGPoint)centroid
                        width:(CGFloat)width
                       height:(CGFloat)height
                 triggerInset:(CGFloat)triggerInset {
    if (centroid.y < height * 0.25) {
        session.singleFingerEventName = @"libactivator.slide-in.right-top";
        session.twoFingerEventName = @"libactivator.two-finger-slide-in.right-top";
    } else if (centroid.y < height * 0.75) {
        session.singleFingerEventName = LAEventNameSlideInFromRight;
        session.twoFingerEventName = LAEventNameTwoFingerSlideInFromRight;
    } else {
        session.singleFingerEventName = @"libactivator.slide-in.right-bottom";
        session.twoFingerEventName = @"libactivator.two-finger-slide-in.right-bottom";
    }
    session.triggerRect = CGRectMake(0.0, 0.0, MAX(0.0, width - triggerInset), height);
}

@end
