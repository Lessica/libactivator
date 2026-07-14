//
//  LATLockScreenClockEventSource.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATLockScreenClockEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface LATLockScreenClockEventSource () <UIGestureRecognizerDelegate>

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, strong) NSHashTable<UIView *> *knownClockViews;
@property(nonatomic, strong) NSHashTable<UIView *> *knownLegacyClockViews;
@property(nonatomic, strong) NSMapTable<UIView *, NSArray<UIGestureRecognizer *> *> *recognizersByClockView;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *originalInteractionByView;
@property(nonatomic, assign) BOOL preciseClockViewObserved;

@end

@implementation LATLockScreenClockEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _knownClockViews = [NSHashTable weakObjectsHashTable];
        _knownLegacyClockViews = [NSHashTable weakObjectsHashTable];
        _recognizersByClockView = [NSMapTable weakToStrongObjectsMapTable];
        _originalInteractionByView = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (NSString *)eventSourceIdentifier {
    return @"lock-screen-clock";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameLockScreenClockDoubleTap,
        LAEventNameLockScreenClockTapHold,
        LAEventNameLockScreenClockSwipeLeft,
        LAEventNameLockScreenClockSwipeRight,
        LAEventNameLockScreenClockSwipeDown,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (void)start {
    LAAssertMainQueue();
    if (self.isStarted || self.isInvalidated) {
        return;
    }

    self.started = YES;
    for (UIView *clockView in self.knownClockViews.allObjects) {
        [self installInClockViewIfNeeded:clockView];
    }
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;

    for (UIView *clockView in self.recognizersByClockView.keyEnumerator.allObjects) {
        for (UIGestureRecognizer *recognizer in [self.recognizersByClockView objectForKey:clockView]) {
            [clockView removeGestureRecognizer:recognizer];
        }
    }
    [self.recognizersByClockView removeAllObjects];

    for (UIView *view in self.originalInteractionByView.keyEnumerator.allObjects) {
        NSNumber *originalInteraction = [self.originalInteractionByView objectForKey:view];
        if (view.isUserInteractionEnabled) {
            view.userInteractionEnabled = originalInteraction.boolValue;
        }
    }
    [self.originalInteractionByView removeAllObjects];
    [self.knownClockViews removeAllObjects];
    [self.knownLegacyClockViews removeAllObjects];
}

#pragma mark - Gesture Recognizer Attachment

- (void)noteLockScreenClockViewDidLoad:(UIView *)clockView {
    LAAssertMainQueue();
    if (!clockView || self.isInvalidated || self.preciseClockViewObserved) {
        return;
    }

    [self.knownLegacyClockViews addObject:clockView];
    [self.knownClockViews addObject:clockView];
    if (self.isStarted) {
        [self installInClockViewIfNeeded:clockView];
    }
}

- (void)notePreciseLockScreenClockViewDidLoad:(UIView *)clockView {
    LAAssertMainQueue();
    if (!clockView || self.isInvalidated) {
        return;
    }

    if (!self.preciseClockViewObserved) {
        self.preciseClockViewObserved = YES;
        for (UIView *legacyClockView in self.knownLegacyClockViews.allObjects) {
            for (UIGestureRecognizer *recognizer in [self.recognizersByClockView objectForKey:legacyClockView]) {
                [legacyClockView removeGestureRecognizer:recognizer];
            }
            [self.recognizersByClockView removeObjectForKey:legacyClockView];
            [self.knownClockViews removeObject:legacyClockView];
        }
        [self.knownLegacyClockViews removeAllObjects];
    }

    [self.knownClockViews addObject:clockView];
    if (self.isStarted) {
        [self installInClockViewIfNeeded:clockView];
    }
}

- (nullable UIView *)lockScreenClockHitViewForContainerView:(UIView *)containerView
                                                       point:(CGPoint)point
                                                   withEvent:(nullable UIEvent *)event {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated) {
        return nil;
    }

    for (UIView *clockView in self.knownClockViews.allObjects) {
        if (![clockView isDescendantOfView:containerView]) {
            continue;
        }

        CGPoint clockPoint = [clockView convertPoint:point fromView:containerView];
        if ([clockView pointInside:clockPoint withEvent:event]) {
            UIView *hitView = [clockView hitTest:clockPoint withEvent:event];
            if (hitView) {
                return hitView;
            }
        }
    }
    return nil;
}

- (void)installInClockViewIfNeeded:(UIView *)clockView {
    LAAssertMainQueue();

    for (UIView *view = clockView; view && ![view isKindOfClass:UIWindow.class] &&
                                 ![NSStringFromClass(view.class) isEqualToString:@"SBFTouchPassThroughView"];
         view = view.superview) {
        [self enableInteractionForViewIfNeeded:view];
    }
    if ([self.recognizersByClockView objectForKey:clockView]) {
        return;
    }

    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(lockScreenClockLongPressRecognized:)];
    UITapGestureRecognizer *doubleTapRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lockScreenClockDoubleTapRecognized:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    [doubleTapRecognizer requireGestureRecognizerToFail:longPressRecognizer];

    UISwipeGestureRecognizer *swipeRightRecognizer = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(lockScreenClockSwipeRightRecognized:)];
    swipeRightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    UISwipeGestureRecognizer *swipeLeftRecognizer = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(lockScreenClockSwipeLeftRecognized:)];
    swipeLeftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer *swipeDownRecognizer = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(lockScreenClockSwipeDownRecognized:)];
    swipeDownRecognizer.direction = UISwipeGestureRecognizerDirectionDown;

    NSArray<UIGestureRecognizer *> *recognizers = @[
        doubleTapRecognizer,
        longPressRecognizer,
        swipeLeftRecognizer,
        swipeRightRecognizer,
        swipeDownRecognizer,
    ];
    for (UIGestureRecognizer *recognizer in recognizers) {
        recognizer.delegate = self;
        [clockView addGestureRecognizer:recognizer];
    }
    [self.recognizersByClockView setObject:recognizers forKey:clockView];
}

- (void)enableInteractionForViewIfNeeded:(nullable UIView *)view {
    if (!view) {
        return;
    }
    if (![self.originalInteractionByView objectForKey:view]) {
        [self.originalInteractionByView setObject:@(view.isUserInteractionEnabled) forKey:view];
    }
    view.userInteractionEnabled = YES;
}

#pragma mark - Recognition

- (void)lockScreenClockLongPressRecognized:(UILongPressGestureRecognizer *)recognizer {
    [self handleRecognizerState:recognizer.state eventName:LAEventNameLockScreenClockTapHold];
}

- (void)lockScreenClockDoubleTapRecognized:(UITapGestureRecognizer *)recognizer {
    [self handleRecognizerState:recognizer.state eventName:LAEventNameLockScreenClockDoubleTap];
}

- (void)lockScreenClockSwipeLeftRecognized:(UISwipeGestureRecognizer *)recognizer {
    [self handleRecognizerState:recognizer.state eventName:LAEventNameLockScreenClockSwipeLeft];
}

- (void)lockScreenClockSwipeRightRecognized:(UISwipeGestureRecognizer *)recognizer {
    [self handleRecognizerState:recognizer.state eventName:LAEventNameLockScreenClockSwipeRight];
}

- (void)lockScreenClockSwipeDownRecognized:(UISwipeGestureRecognizer *)recognizer {
    [self handleRecognizerState:recognizer.state eventName:LAEventNameLockScreenClockSwipeDown];
}

- (BOOL)handleRecognizerState:(UIGestureRecognizerState)state eventName:(NSString *)eventName {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated || ![self.eventNames containsObject:eventName]) {
        return NO;
    }

    UIGestureRecognizerState expectedState = [eventName isEqualToString:LAEventNameLockScreenClockTapHold]
                                                 ? UIGestureRecognizerStateBegan
                                                 : UIGestureRecognizerStateEnded;
    if (state != expectedState) {
        return NO;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
    HBLogInfo(@"Dispatched lock screen clock gesture event=%@ mode=%@", eventName, eventMode);
    return YES;
}

- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(__unused UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#if DEBUG
#pragma mark - Testing Hooks

- (BOOL)la_testingHandleRecognizerState:(UIGestureRecognizerState)state eventName:(NSString *)eventName {
    return [self handleRecognizerState:state eventName:eventName];
}

- (NSUInteger)la_testingKnownClockViewCount {
    return self.knownClockViews.count;
}

- (nullable NSArray<UIGestureRecognizer *> *)la_testingInstalledRecognizersInClockView:(UIView *)clockView {
    return [self.recognizersByClockView objectForKey:clockView];
}
#endif

@end
