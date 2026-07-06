//
//  LATEventSourceInterestGate.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceInterestGate.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>

static NSUInteger const LATEventSourceInterestFamilyCount = LATEventSourceInterestFamilySpringBoardIconGesture + 1;

@interface LATEventSourceInterestGate ()

// Dependencies
@property(nonatomic, weak) LAActivator *activator;

// Lifecycle
@property(nonatomic, assign, getter=isStarted) BOOL started;

// Cache
@property(nonatomic, assign) BOOL hasCachedInterestMask;
@property(nonatomic, assign) NSUInteger cachedInterestMask;
@property(nonatomic, copy, nullable) NSString *cachedEventMode;

#if DEBUG
// Testing hooks
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<NSString *> *> *testingEventNamesByFamily;
#endif

@end

@implementation LATEventSourceInterestGate

#pragma mark - Lifecycle

- (instancetype)initWithActivator:(LAActivator *)activator {
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
#if DEBUG
        _testingEventNamesByFamily = [[NSMutableDictionary alloc] init];
#endif
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)start {
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(invalidateInterestCache:)
                   name:LAActivatorAssignmentsChangedNotification
                 object:self.activator];
    [center addObserver:self
               selector:@selector(invalidateInterestCache:)
                   name:LAActivatorEventModeChangedNotification
                 object:self.activator];
    [center addObserver:self
               selector:@selector(invalidateInterestCache:)
                   name:LAActivatorAvailableEventsChangedNotification
                 object:self.activator];
    [center addObserver:self
               selector:@selector(invalidateInterestCache:)
                   name:LAActivatorAvailableListenersChangedNotification
                 object:self.activator];
}

#pragma mark - Interest

- (BOOL)isInterestedInFamily:(LATEventSourceInterestFamily)family {
    LAAssertMainQueue();
    if (!self.started || !self.activator) {
        return YES;
    }

    [self updateInterestMaskIfNeeded];
    return (self.cachedInterestMask & [self maskForFamily:family]) != 0;
}

- (void)updateInterestMaskIfNeeded {
    NSString *eventMode = [self currentEventModeCacheKey];
    if (self.hasCachedInterestMask && [self.cachedEventMode isEqualToString:eventMode]) {
        return;
    }

    self.cachedInterestMask = [self calculateInterestMask];
    self.cachedEventMode = eventMode;
    self.hasCachedInterestMask = YES;
}

- (NSUInteger)calculateInterestMask {
    NSUInteger interestMask = 0;
    for (NSUInteger family = 0; family < LATEventSourceInterestFamilyCount; family++) {
        LATEventSourceInterestFamily interestFamily = (LATEventSourceInterestFamily)family;
        if ([self calculateInterestInFamily:interestFamily]) {
            interestMask |= [self maskForFamily:interestFamily];
        }
    }
    return interestMask;
}

- (NSUInteger)maskForFamily:(LATEventSourceInterestFamily)family {
    return (NSUInteger)1 << family;
}

- (NSString *)currentEventModeCacheKey {
    NSString *eventMode = self.activator.currentEventMode;
    return eventMode.length > 0 ? eventMode : @"";
}

- (BOOL)calculateInterestInFamily:(LATEventSourceInterestFamily)family {
    LAActivator *activator = self.activator;
    if (!activator) {
        return YES;
    }

    for (NSString *eventName in [self eventNamesForFamily:family]) {
        if (eventName.length == 0) {
            continue;
        }
        if ([activator assignedListenerNameForEvent:[LAEvent eventWithName:eventName]].length > 0) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)eventNamesForFamily:(LATEventSourceInterestFamily)family {
#if DEBUG
    NSArray<NSString *> *testingEventNames = self.testingEventNamesByFamily[@(family)];
    if (testingEventNames) {
        return testingEventNames;
    }
#endif

    switch (family) {
    case LATEventSourceInterestFamilyEdgeGesture:
        return [self edgeGestureEventNames];
    case LATEventSourceInterestFamilyForceTouch:
        return [self forceTouchEventNames];
    case LATEventSourceInterestFamilyStatusBar:
        return [self statusBarEventNames];
    case LATEventSourceInterestFamilyMultiTouch:
        return [self multiTouchEventNames];
    case LATEventSourceInterestFamilySpringBoardIconGesture:
        return [self springBoardIconGestureEventNames];
    }
}

- (NSArray<NSString *> *)edgeGestureEventNames {
    return @[
        LAEventNameSlideInFromTopLeft,
        LAEventNameStatusBarSwipeDown,
        LAEventNameSlideInFromTopRight,
        LAEventNameSlideInFromBottomLeft,
        LAEventNameSlideInFromBottom,
        LAEventNameSlideInFromBottomRight,
        LAEventNameSlideInFromLeftTop,
        LAEventNameSlideInFromLeft,
        LAEventNameSlideInFromLeftBottom,
        LAEventNameSlideInFromRightTop,
        LAEventNameSlideInFromRight,
        LAEventNameSlideInFromRightBottom,
        LAEventNameTwoFingerSlideInFromTopLeft,
        LAEventNameTwoFingerSlideInFromTop,
        LAEventNameTwoFingerSlideInFromTopRight,
        LAEventNameTwoFingerSlideInFromBottomLeft,
        LAEventNameTwoFingerSlideInFromBottom,
        LAEventNameTwoFingerSlideInFromBottomRight,
        LAEventNameTwoFingerSlideInFromLeftTop,
        LAEventNameTwoFingerSlideInFromLeft,
        LAEventNameTwoFingerSlideInFromLeftBottom,
        LAEventNameTwoFingerSlideInFromRightTop,
        LAEventNameTwoFingerSlideInFromRight,
        LAEventNameTwoFingerSlideInFromRightBottom,
        LAEventScreenBottomSwipeLeft,
        LAEventScreenBottomSwipeRight,
        LAEventScreenLeftSwipeDown,
        LAEventScreenLeftSwipeUp,
        LAEventScreenRightSwipeDown,
        LAEventScreenRightSwipeUp,
        LAEventNameDragOffLeft,
        LAEventNameDragOffRight,
        LAEventNameDragOffTop,
        LAEventNameDragOffBottom,
        LAEventNameFingerprintSensorPressSingleAndSlideIn,
    ];
}

- (NSArray<NSString *> *)forceTouchEventNames {
    return @[
        LAEventNameForceTouchStatusBar,
        LAEventNameForceTouchScreenLeft,
        LAEventNameForceTouchScreenRight,
        LAEventNameForceTouchScreenBottomLeft,
        LAEventNameForceTouchScreenBottom,
        LAEventNameForceTouchScreenBottomRight,
    ];
}

- (NSArray<NSString *> *)statusBarEventNames {
    return @[
        LAEventNameStatusBarTapSingle,
        LAEventNameStatusBarTapSingleLeft,
        LAEventNameStatusBarTapSingleRight,
        LAEventNameStatusBarTapDouble,
        LAEventNameStatusBarTapDoubleLeft,
        LAEventNameStatusBarTapDoubleRight,
        LAEventNameStatusBarHold,
        LAEventNameStatusBarHoldLeft,
        LAEventNameStatusBarHoldRight,
        LAEventNameStatusBarSwipeLeft,
        LAEventNameStatusBarSwipeRight,
        LAEventNameStatusBarSwipeDown,
    ];
}

- (NSArray<NSString *> *)multiTouchEventNames {
    return @[
        LAEventNameThreeFingerTap,
        LAEventNameThreeFingerPinch,
        LAEventNameThreeFingerSpread,
        LAEventNameFourFingerTap,
        LAEventNameFourFingerPinch,
        LAEventNameFourFingerSpread,
        LAEventNameFiveFingerTap,
        LAEventNameFiveFingerPinch,
        LAEventNameFiveFingerSpread,
    ];
}

- (NSArray<NSString *> *)springBoardIconGestureEventNames {
    return @[
        LAEventNameSpringBoardPinch,
        LAEventNameSpringBoardSpread,
        LAEventNameSpringBoardIconFlickUp,
        LAEventNameSpringBoardIconFlickDown,
        LAEventNameSpringBoardIconFlickLeft,
        LAEventNameSpringBoardIconFlickRight,
    ];
}

#pragma mark - Cache

- (void)invalidateInterestCache:(__unused NSNotification *)notification {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self invalidateInterestCache:nil];
        });
        return;
    }

    LAAssertMainQueue();
    self.hasCachedInterestMask = NO;
    self.cachedInterestMask = 0;
    self.cachedEventMode = nil;
}

#if DEBUG
#pragma mark - Testing Hooks

- (void)la_testingInvalidate {
    [self invalidateInterestCache:nil];
}

- (NSArray<NSString *> *)la_testingEventNamesForFamily:(LATEventSourceInterestFamily)family {
    return [self eventNamesForFamily:family];
}

- (void)la_testingSetEventNames:(NSArray<NSString *> *)eventNames forFamily:(LATEventSourceInterestFamily)family {
    self.testingEventNamesByFamily[@(family)] = [eventNames copy] ?: @[];
    [self invalidateInterestCache:nil];
}
#endif

@end
