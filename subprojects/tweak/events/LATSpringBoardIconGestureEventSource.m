//
//  LATSpringBoardIconGestureEventSource.m
//  libactivator
//
//  Created by Lessica on 7/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATSpringBoardIconGestureEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"
#import "LATEventSourceRegistry.h"

#import <Activator/Activator.h>
#import <HBLog.h>

static CGFloat const LATSpringBoardIconGesturePinchThreshold = 0.95;
static CGFloat const LATSpringBoardIconGestureSpreadThreshold = 1.05;

@interface LATSpringBoardIconPinchSession : NSObject

@property(nonatomic, assign, getter=isActive) BOOL active;
@property(nonatomic, assign) BOOL hasSentEvent;

@end

@implementation LATSpringBoardIconPinchSession
@end

@interface LATSpringBoardIconGestureEventSource ()

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, strong) NSHashTable<UIPinchGestureRecognizer *> *installedRecognizers;
@property(nonatomic, strong) NSMapTable<UIScrollView *, NSNumber *> *minimumZoomScalesByScrollView;
@property(nonatomic, strong) NSMapTable<id, LATSpringBoardIconPinchSession *> *sessionsByRecognizer;

#if DEBUG
@property(nonatomic, strong) NSObject *testingRecognizerKey;
#endif

@end

@implementation LATSpringBoardIconGestureEventSource

#pragma mark - LATEventSource

- (NSString *)eventSourceIdentifier {
    return @"springboard-icon-gesture";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameSpringBoardPinch,
        LAEventNameSpringBoardSpread,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAssignedInCurrentMode;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _installedRecognizers = [NSHashTable weakObjectsHashTable];
        _minimumZoomScalesByScrollView = [NSMapTable weakToStrongObjectsMapTable];
        _sessionsByRecognizer = [NSMapTable weakToStrongObjectsMapTable];
#if DEBUG
        _testingRecognizerKey = [[NSObject alloc] init];
#endif
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
        return;
    }
    self.started = YES;
    if ([self shouldProcessEvents]) {
        [self installInExistingIconScrollViews];
    }
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self removeRecognizerTargetsAndRestoreScrollViews];
}

- (void)eventSourceInterestDidChange:(BOOL)interested {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    if (interested && self.started) {
        [self installInExistingIconScrollViews];
    } else if (!interested) {
        [self removeRecognizerTargetsAndRestoreScrollViews];
    }
}

- (void)eventSourceInterestedEventNamesDidChange:(__unused NSSet<NSString *> *)interestedEventNames {
    LAAssertMainQueue();
    [self.sessionsByRecognizer removeAllObjects];
}

#pragma mark - Gesture Recognizer Attachment

- (void)noteIconScrollViewDidInitialize:(UIScrollView *)scrollView {
    LAAssertMainQueue();
    if (!self.started || !scrollView || ![self shouldProcessEvents]) {
        return;
    }

    [self configureIconScrollViewForPinchRecognition:scrollView];
    [self installTargetOnPinchGestureRecognizer:scrollView.pinchGestureRecognizer];
}

- (void)configureIconScrollViewForPinchRecognition:(UIScrollView *)scrollView {
    LAAssertMainQueue();

    if (scrollView.minimumZoomScale > LATSpringBoardIconGesturePinchThreshold) {
        if (![self.minimumZoomScalesByScrollView objectForKey:scrollView]) {
            [self.minimumZoomScalesByScrollView setObject:@(scrollView.minimumZoomScale) forKey:scrollView];
        }
        scrollView.minimumZoomScale = LATSpringBoardIconGesturePinchThreshold;
    }
}

- (void)installTargetOnPinchGestureRecognizer:(nullable UIPinchGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    if (!recognizer || [self.installedRecognizers containsObject:recognizer]) {
        return;
    }

    [recognizer addTarget:self action:@selector(iconScrollViewPinchGestureRecognized:)];
    [self.installedRecognizers addObject:recognizer];
}

- (void)installInExistingIconScrollViews {
    LAAssertMainQueue();

    Class iconScrollViewClass = NSClassFromString(@"SBIconScrollView");
    if (!iconScrollViewClass) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            [self installInIconScrollViewDescendantsOfView:window iconScrollViewClass:iconScrollViewClass];
        }
    }
}

- (void)installInIconScrollViewDescendantsOfView:(UIView *)view iconScrollViewClass:(Class)iconScrollViewClass {
    LAAssertMainQueue();
    if ([view isKindOfClass:iconScrollViewClass] && [view isKindOfClass:UIScrollView.class]) {
        [self noteIconScrollViewDidInitialize:(UIScrollView *)view];
    }

    for (UIView *subview in view.subviews) {
        [self installInIconScrollViewDescendantsOfView:subview iconScrollViewClass:iconScrollViewClass];
    }
}

- (void)removeRecognizerTargetsAndRestoreScrollViews {
    LAAssertMainQueue();

    for (UIPinchGestureRecognizer *recognizer in self.installedRecognizers.allObjects) {
        [recognizer removeTarget:self action:@selector(iconScrollViewPinchGestureRecognized:)];
    }
    [self.installedRecognizers removeAllObjects];
    [self.sessionsByRecognizer removeAllObjects];

    for (UIScrollView *scrollView in self.minimumZoomScalesByScrollView.keyEnumerator) {
        NSNumber *minimumZoomScale = [self.minimumZoomScalesByScrollView objectForKey:scrollView];
        if (minimumZoomScale && scrollView.minimumZoomScale == LATSpringBoardIconGesturePinchThreshold) {
            scrollView.minimumZoomScale = minimumZoomScale.doubleValue;
        }
    }
    [self.minimumZoomScalesByScrollView removeAllObjects];
}

#pragma mark - Interest

- (BOOL)shouldProcessEvents {
    LAAssertMainQueue();
    LATEventSourceRegistry *eventSourceRegistry = self.eventSourceRegistry;
    return !eventSourceRegistry || [eventSourceRegistry isInterestedInEventSource:self];
}

#pragma mark - Recognition

- (void)iconScrollViewPinchGestureRecognized:(UIPinchGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    [self handlePinchRecognizer:recognizer scale:recognizer.scale state:recognizer.state bounds:recognizer.view.bounds];
}

- (nullable NSString *)handlePinchRecognizer:(id)recognizer
                                       scale:(CGFloat)scale
                                       state:(UIGestureRecognizerState)state
                                      bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (!recognizer) {
        return nil;
    }

    if (!self.started || ![self shouldProcessEvents]) {
        [self.sessionsByRecognizer removeObjectForKey:recognizer];
        return nil;
    }

    if (state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateFailed ||
        state == UIGestureRecognizerStateEnded) {
        [self.sessionsByRecognizer removeObjectForKey:recognizer];
        return nil;
    }

    if (state != UIGestureRecognizerStateBegan && state != UIGestureRecognizerStateChanged) {
        return nil;
    }

    LATSpringBoardIconPinchSession *session = [self.sessionsByRecognizer objectForKey:recognizer];
    if (!session || state == UIGestureRecognizerStateBegan) {
        session = [[LATSpringBoardIconPinchSession alloc] init];
        session.active = YES;
        [self.sessionsByRecognizer setObject:session forKey:recognizer];
    }

    if (!session.isActive || session.hasSentEvent) {
        return nil;
    }

    NSString *eventName = nil;
    if (scale < LATSpringBoardIconGesturePinchThreshold) {
        eventName = LAEventNameSpringBoardPinch;
    } else if (scale > LATSpringBoardIconGestureSpreadThreshold) {
        eventName = LAEventNameSpringBoardSpread;
    }

    if (eventName.length == 0) {
        return nil;
    }

    session.hasSentEvent = YES;
    [self sendEventWithName:eventName scale:scale bounds:bounds];
    return eventName;
}

#pragma mark - Event Dispatch

- (void)sendEventWithName:(NSString *)eventName scale:(CGFloat)scale bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (eventName.length == 0) {
        return;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [LASharedActivator sendEventToListener:event];
    HBLogInfo(@"Classified and dispatched SpringBoard icon gesture event=%@ scale=%.3f bounds=%@", eventName, scale,
              NSStringFromCGRect(bounds));
}

#if DEBUG
#pragma mark - Testing Hooks

- (nullable NSString *)la_testingHandlePinchScale:(CGFloat)scale
                                            state:(UIGestureRecognizerState)state
                                           bounds:(CGRect)bounds {
    return [self handlePinchRecognizer:self.testingRecognizerKey scale:scale state:state bounds:bounds];
}

- (BOOL)la_testingHasRecognitionState {
    return [self.sessionsByRecognizer objectForKey:self.testingRecognizerKey] != nil;
}
#endif

@end
