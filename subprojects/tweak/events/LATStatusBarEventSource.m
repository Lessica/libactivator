//
//  LATStatusBarEventSource.m
//  libactivator
//
//  Created by OpenAI on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATStatusBarEventSource.h"

#import "LAActivator+Private.h"
#import "LATQueueAssertions.h"

static NSTimeInterval const LATStatusBarEventSourceHoldDelay = 0.5;
static NSTimeInterval const LATStatusBarEventSourceTapDelay = 0.33;
static NSTimeInterval const LATStatusBarEventSourceCancelledTapMaximumDuration = LATStatusBarEventSourceHoldDelay;
static CGFloat const LATStatusBarEventSourceHorizontalSwipeThreshold = 50.0;
static CGFloat const LATStatusBarEventSourceVerticalSwipeThreshold = 10.0;

@interface LATStatusBarTouchSession : NSObject

// Geometry snapshot
@property(nonatomic, assign) CGRect bounds;
@property(nonatomic, assign) CGPoint startPoint;
@property(nonatomic, assign) NSTimeInterval startTimestamp;

// Recognition state
@property(nonatomic, assign) BOOL hasSentEvent;
@property(nonatomic, assign) BOOL touchActive;

// Timer generations
@property(nonatomic, assign) NSUInteger holdGeneration;
@property(nonatomic, assign) NSUInteger tapGeneration;

// Derived event names
@property(nonatomic, copy, nullable) NSString *doubleTapEventName;
@property(nonatomic, copy, nullable) NSString *holdEventName;
@property(nonatomic, copy, nullable) NSString *tapEventName;

@end

@implementation LATStatusBarTouchSession
@end

@interface LATStatusBarEventSource ()

// Lifecycle
@property(nonatomic, assign) BOOL started;

// Active sessions
@property(nonatomic, strong) NSMapTable<id, LATStatusBarTouchSession *> *sessionsByStatusBarView;

@end

@implementation LATStatusBarEventSource

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionsByStatusBarView = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (void)start {
    LATAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;
}

#pragma mark - Touch Entry Points

- (void)noteStatusBarView:(UIView *)view touchesBegan:(NSSet<UITouch *> *)touches withEvent:(__unused UIEvent *)event {
    LATAssertMainQueue();

    UITouch *touch = touches.anyObject;
    if (!touch) {
        return;
    }

    [self noteTouchBeganInStatusBarView:view
                                 bounds:view.bounds
                               location:[touch locationInView:view]
                               tapCount:touch.tapCount];
}

- (void)noteStatusBarView:(UIView *)view touchesMoved:(NSSet<UITouch *> *)touches withEvent:(__unused UIEvent *)event {
    LATAssertMainQueue();

    UITouch *touch = touches.anyObject;
    if (!touch) {
        return;
    }

    [self noteTouchMovedInStatusBarView:view bounds:view.bounds location:[touch locationInView:view]];
}

- (void)noteStatusBarView:(UIView *)view touchesEnded:(NSSet<UITouch *> *)touches withEvent:(__unused UIEvent *)event {
    LATAssertMainQueue();

    UITouch *touch = touches.anyObject;
    if (!touch) {
        return;
    }

    [self noteTouchEndedInStatusBarView:view tapCount:touch.tapCount];
}

- (void)noteStatusBarView:(UIView *)view
         touchesCancelled:(NSSet<UITouch *> *)touches
                withEvent:(__unused UIEvent *)event {
    LATAssertMainQueue();

    UITouch *touch = touches.anyObject;
    if (!touch) {
        [self cancelSessionForStatusBarView:view];
        return;
    }

    [self noteTouchCancelledInStatusBarView:view
                                     bounds:view.bounds
                                   location:[touch locationInView:view]
                                   tapCount:touch.tapCount];
}

#pragma mark - Recognition

- (void)noteTouchBeganInStatusBarView:(id)view
                               bounds:(CGRect)bounds
                             location:(CGPoint)location
                             tapCount:(__unused NSUInteger)tapCount {
    LATAssertMainQueue();
    if (!self.started || !view) {
        return;
    }

    [self cancelSessionForStatusBarView:view];

    LATStatusBarTouchSession *session = [[LATStatusBarTouchSession alloc] init];
    session.bounds = bounds;
    session.startPoint = location;
    session.startTimestamp = [NSDate timeIntervalSinceReferenceDate];
    session.touchActive = YES;
    [self configureEventNamesForSession:session startPoint:location bounds:bounds];
    [self.sessionsByStatusBarView setObject:session forKey:view];
    [self scheduleHoldForStatusBarView:view session:session];
}

- (void)noteTouchMovedInStatusBarView:(id)view bounds:(CGRect)bounds location:(CGPoint)location {
    LATAssertMainQueue();
    if (!self.started || !view) {
        return;
    }

    LATStatusBarTouchSession *session = [self.sessionsByStatusBarView objectForKey:view];
    if (!session || session.hasSentEvent) {
        return;
    }

    session.bounds = bounds;

    CGFloat deltaX = location.x - session.startPoint.x;
    CGFloat deltaY = location.y - session.startPoint.y;
    if ((deltaX * deltaX) > (deltaY * deltaY)) {
        if (deltaX > LATStatusBarEventSourceHorizontalSwipeThreshold) {
            [self sendEventWithName:LAEventNameStatusBarSwipeRight statusBarView:view session:session];
        } else if (deltaX < -LATStatusBarEventSourceHorizontalSwipeThreshold) {
            [self sendEventWithName:LAEventNameStatusBarSwipeLeft statusBarView:view session:session];
        }
    } else if (deltaY > LATStatusBarEventSourceVerticalSwipeThreshold) {
        [self sendEventWithName:LAEventNameStatusBarSwipeDown statusBarView:view session:session];
    }
}

- (void)noteTouchEndedInStatusBarView:(id)view tapCount:(NSUInteger)tapCount {
    LATAssertMainQueue();
    if (!self.started || !view) {
        return;
    }

    LATStatusBarTouchSession *session = [self.sessionsByStatusBarView objectForKey:view];
    if (!session) {
        return;
    }

    session.touchActive = NO;
    [self cancelHoldForSession:session];
    [self cancelTapForSession:session];
    if (session.hasSentEvent) {
        [self.sessionsByStatusBarView removeObjectForKey:view];
        return;
    }

    if (tapCount == 2) {
        [self sendEventWithName:session.doubleTapEventName statusBarView:view session:session];
        return;
    }

    [self scheduleTapForStatusBarView:view session:session];
}

- (void)noteTouchCancelledInStatusBarView:(id)view
                                   bounds:(CGRect)bounds
                                 location:(CGPoint)location
                                 tapCount:(NSUInteger)tapCount {
    LATAssertMainQueue();
    if (![self shouldTreatCancellationAsTapForStatusBarView:view bounds:bounds location:location]) {
        [self cancelSessionForStatusBarView:view];
        return;
    }

    [self noteTouchEndedInStatusBarView:view tapCount:tapCount];
}

- (BOOL)shouldTreatCancellationAsTapForStatusBarView:(id)view bounds:(CGRect)bounds location:(CGPoint)location {
    LATAssertMainQueue();
    if (!self.started || !view) {
        return NO;
    }

    LATStatusBarTouchSession *session = [self.sessionsByStatusBarView objectForKey:view];
    if (!session || session.hasSentEvent || !session.touchActive) {
        return NO;
    }

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - session.startTimestamp;
    if (elapsed < 0.0 || elapsed >= LATStatusBarEventSourceCancelledTapMaximumDuration) {
        return NO;
    }

    CGRect effectiveBounds = CGRectIsEmpty(bounds) ? session.bounds : bounds;
    if (CGRectIsEmpty(effectiveBounds) || !CGRectContainsPoint(effectiveBounds, location)) {
        return NO;
    }

    return ![self movementExceedsSwipeThresholdFromPoint:session.startPoint toPoint:location];
}

- (BOOL)movementExceedsSwipeThresholdFromPoint:(CGPoint)startPoint toPoint:(CGPoint)location {
    CGFloat deltaX = location.x - startPoint.x;
    CGFloat deltaY = location.y - startPoint.y;
    if ((deltaX * deltaX) > (deltaY * deltaY)) {
        return fabs(deltaX) > LATStatusBarEventSourceHorizontalSwipeThreshold;
    }
    return deltaY > LATStatusBarEventSourceVerticalSwipeThreshold;
}

- (void)configureEventNamesForSession:(LATStatusBarTouchSession *)session
                           startPoint:(CGPoint)startPoint
                               bounds:(CGRect)bounds {
    LATAssertMainQueue();

    CGFloat width = CGRectGetWidth(bounds);
    if (width > 0.0 && startPoint.x < width * 0.25) {
        session.holdEventName = LAEventNameStatusBarHoldLeft;
        session.tapEventName = LAEventNameStatusBarTapSingleLeft;
        session.doubleTapEventName = LAEventNameStatusBarTapDoubleLeft;
    } else if (width > 0.0 && startPoint.x >= width * 0.75) {
        session.holdEventName = LAEventNameStatusBarHoldRight;
        session.tapEventName = LAEventNameStatusBarTapSingleRight;
        session.doubleTapEventName = LAEventNameStatusBarTapDoubleRight;
    } else {
        session.holdEventName = LAEventNameStatusBarHold;
        session.tapEventName = LAEventNameStatusBarTapSingle;
        session.doubleTapEventName = LAEventNameStatusBarTapDouble;
    }
}

#pragma mark - Timers

- (void)scheduleHoldForStatusBarView:(id)view session:(LATStatusBarTouchSession *)session {
    LATAssertMainQueue();

    session.holdGeneration += 1;
    NSUInteger generation = session.holdGeneration;
    __weak typeof(self) weakSelf = self;
    __weak id weakView = view;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATStatusBarEventSourceHoldDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       id strongView = weakView;
                       [strongSelf sendHoldForStatusBarView:strongView session:session generation:generation];
                   });
}

- (void)scheduleTapForStatusBarView:(id)view session:(LATStatusBarTouchSession *)session {
    LATAssertMainQueue();

    session.tapGeneration += 1;
    NSUInteger generation = session.tapGeneration;
    __weak typeof(self) weakSelf = self;
    __weak id weakView = view;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATStatusBarEventSourceTapDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       __strong typeof(weakSelf) strongSelf = weakSelf;
                       id strongView = weakView;
                       [strongSelf sendTapForStatusBarView:strongView session:session generation:generation];
                   });
}

- (void)sendHoldForStatusBarView:(id)view
                         session:(LATStatusBarTouchSession *)session
                      generation:(NSUInteger)generation {
    LATAssertMainQueue();

    if (!view || generation != session.holdGeneration || !session.touchActive || session.hasSentEvent ||
        [self.sessionsByStatusBarView objectForKey:view] != session) {
        return;
    }

    [self sendEventWithName:session.holdEventName statusBarView:view session:session];
}

- (void)sendTapForStatusBarView:(id)view session:(LATStatusBarTouchSession *)session generation:(NSUInteger)generation {
    LATAssertMainQueue();

    if (!view || generation != session.tapGeneration || session.touchActive || session.hasSentEvent ||
        [self.sessionsByStatusBarView objectForKey:view] != session) {
        return;
    }

    [self sendEventWithName:session.tapEventName statusBarView:view session:session];
}

- (void)cancelHoldForSession:(LATStatusBarTouchSession *)session {
    LATAssertMainQueue();
    session.holdGeneration += 1;
}

- (void)cancelTapForSession:(LATStatusBarTouchSession *)session {
    LATAssertMainQueue();
    session.tapGeneration += 1;
}

- (void)cancelSessionForStatusBarView:(id)view {
    LATAssertMainQueue();
    if (!view) {
        return;
    }

    LATStatusBarTouchSession *session = [self.sessionsByStatusBarView objectForKey:view];
    if (session) {
        [self cancelHoldForSession:session];
        [self cancelTapForSession:session];
        session.touchActive = NO;
    }
    [self.sessionsByStatusBarView removeObjectForKey:view];
}

#pragma mark - Event Dispatch

- (void)sendEventWithName:(NSString *)eventName statusBarView:(id)view session:(LATStatusBarTouchSession *)session {
    LATAssertMainQueue();
    if (eventName.length == 0 || session.hasSentEvent) {
        return;
    }

    session.hasSentEvent = YES;
    session.touchActive = NO;
    [self cancelHoldForSession:session];
    [self cancelTapForSession:session];

    LAEvent *event = [LAEvent eventWithName:eventName mode:[self currentEventMode]];
    [LASharedActivator sendEventToListener:event];
    [self.sessionsByStatusBarView removeObjectForKey:view];
}

- (NSString *)currentEventMode {
    LATAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

#if DEBUG
- (void)la_testingNoteTouchBeganInStatusBarView:(id)view
                                         bounds:(CGRect)bounds
                                       location:(CGPoint)location
                                       tapCount:(NSUInteger)tapCount {
    [self noteTouchBeganInStatusBarView:view bounds:bounds location:location tapCount:tapCount];
}

- (void)la_testingNoteTouchMovedInStatusBarView:(id)view bounds:(CGRect)bounds location:(CGPoint)location {
    [self noteTouchMovedInStatusBarView:view bounds:bounds location:location];
}

- (void)la_testingNoteTouchEndedInStatusBarView:(id)view tapCount:(NSUInteger)tapCount {
    [self noteTouchEndedInStatusBarView:view tapCount:tapCount];
}

- (void)la_testingNoteTouchCancelledInStatusBarView:(id)view {
    [self cancelSessionForStatusBarView:view];
}

- (void)la_testingNoteTouchCancelledInStatusBarView:(id)view
                                             bounds:(CGRect)bounds
                                           location:(CGPoint)location
                                           tapCount:(NSUInteger)tapCount {
    [self noteTouchCancelledInStatusBarView:view bounds:bounds location:location tapCount:tapCount];
}
#endif

@end
