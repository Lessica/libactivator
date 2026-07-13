//
//  LATMultiTouchEventSource.m
//  libactivator
//
//  Created by Lessica on 7/1/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMultiTouchEventSource.h"

#import "LAQueueAssertions.h"
#import "LATMultiTouchGestureRecognizer.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface LATMultiTouchEventSource () <UIGestureRecognizerDelegate>

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign, getter=isInterested) BOOL interested;
@property(nonatomic, strong) LATMultiTouchGestureRecognizer *gestureRecognizer;
@property(nonatomic, weak, nullable) UIWindow *gestureWindow;

@end

@implementation LATMultiTouchEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (NSString *)eventSourceIdentifier {
    return @"multi-touch";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameThreeFingerTap,
        LAEventNameThreeFingerPinch,
        LAEventNameThreeFingerSpread,
        LAEventNameFourFingerTap,
        LAEventNameFourFingerPinch,
        LAEventNameFourFingerSpread,
        LAEventNameFiveFingerTap,
        LAEventNameFiveFingerPinch,
        LAEventNameFiveFingerSpread,
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
        _gestureRecognizer = [[LATMultiTouchGestureRecognizer alloc] initWithTarget:self
                                                                             action:@selector(multiTouchRecognized:)];
        _gestureRecognizer.delegate = self;
        _gestureRecognizer.enabled = NO;
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
    self.gestureRecognizer.enabled = NO;
    [self.gestureRecognizer reset];
    [self.gestureRecognizer.view removeGestureRecognizer:self.gestureRecognizer];
    [self.gestureRecognizer removeTarget:self action:@selector(multiTouchRecognized:)];
    self.gestureWindow = nil;
}

- (void)eventSourceInterestDidChange:(BOOL)interested {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.interested = interested;
    self.gestureRecognizer.enabled = interested;
    if (!interested) {
        [self.gestureRecognizer reset];
    }
}

- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames {
    LAAssertMainQueue();
    self.interested = interestedEventNames.count > 0;
    self.gestureRecognizer.enabled = self.isInterested;
    [self.gestureRecognizer reset];
}

#pragma mark - Touch Entry Points

- (void)noteSystemGestureWindow:(UIWindow *)window event:(UIEvent *)event {
    LAAssertMainQueue();
    if (!self.started || !window || !event) {
        return;
    }

    [self installGestureRecognizerIfNeededInWindow:window];
    [self updateGestureRecognizerEnabledState];
}

#pragma mark - Interest

- (BOOL)shouldProcessEvents {
    LAAssertMainQueue();
    return self.isInterested;
}

#pragma mark - Recognition

- (void)installGestureRecognizerIfNeededInWindow:(UIWindow *)window {
    LAAssertMainQueue();
    if (self.gestureWindow == window && self.gestureRecognizer.view == window) {
        return;
    }

    if (self.gestureRecognizer.view) {
        [self.gestureRecognizer.view removeGestureRecognizer:self.gestureRecognizer];
    }

    self.gestureWindow = window;
    [window addGestureRecognizer:self.gestureRecognizer];
}

- (void)updateGestureRecognizerEnabledState {
    LAAssertMainQueue();
    BOOL enabled = [self shouldProcessEvents];
    if (self.gestureRecognizer.enabled == enabled) {
        if (!enabled) {
            [self.gestureRecognizer reset];
        }
        return;
    }

    self.gestureRecognizer.enabled = enabled;
    if (!enabled) {
        [self.gestureRecognizer reset];
    }
}

- (void)multiTouchRecognized:(LATMultiTouchGestureRecognizer *)gestureRecognizer {
    LAAssertMainQueue();
    if (gestureRecognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    [self handleRecognizedEventName:gestureRecognizer.recognizedEventName
                         touchCount:gestureRecognizer.recognizedTouchCount
                             bounds:gestureRecognizer.view.bounds];
}

- (nullable NSString *)handleRecognizedEventName:(NSString *)eventName
                                      touchCount:(NSUInteger)touchCount
                                          bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (!self.started) {
        return nil;
    }

    if (eventName.length > 0) {
        [self sendEventWithName:eventName touchCount:touchCount bounds:bounds];
    }
    return eventName;
}

#pragma mark - Event Dispatch

- (void)sendEventWithName:(NSString *)eventName touchCount:(NSUInteger)touchCount bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (eventName.length == 0) {
        return;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:[self currentEventMode]];
    [self.eventDispatcher dispatchEvent:event];
    HBLogInfo(@"Classified and dispatched multi-touch event=%@ touchCount=%lu bounds=%@", eventName,
              (unsigned long)touchCount, NSStringFromCGRect(bounds));
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();

    NSString *eventMode = self.modeProvider.currentEventMode;
    return eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(__unused UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#if DEBUG
#pragma mark - Testing Hooks

- (nullable NSString *)la_testingUpdateWithTouchLocations:(NSArray<NSValue *> *)touchLocations
                                                    phase:(UITouchPhase)phase
                                                   bounds:(CGRect)bounds
                                                timestamp:(__unused NSTimeInterval)timestamp {
    if (!self.started) {
        return nil;
    }

    if (![self shouldProcessEvents]) {
        [self.gestureRecognizer reset];
        return nil;
    }

    NSString *eventName = [self.gestureRecognizer la_testingUpdateWithTouchLocations:touchLocations
                                                                               phase:phase
                                                                              bounds:bounds
                                                                           timestamp:timestamp];
    return [self handleRecognizedEventName:eventName touchCount:touchLocations.count bounds:bounds];
}

- (BOOL)la_testingHasRecognitionState {
    return [self.gestureRecognizer la_testingHasRecognitionState];
}
#endif

@end
