//
//  LATMultiTouchEventSource.m
//  libactivator
//
//  Created by Lessica on 7/1/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMultiTouchEventSource.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"
#import "LATEventSourceInterestGate.h"
#import "LATMultiTouchGestureRecognizer.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface LATMultiTouchEventSource () <UIGestureRecognizerDelegate>

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong) LATMultiTouchGestureRecognizer *gestureRecognizer;
@property(nonatomic, weak, nullable) UIWindow *gestureWindow;

@end

@implementation LATMultiTouchEventSource

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _gestureRecognizer = [[LATMultiTouchGestureRecognizer alloc] initWithTarget:self
                                                                             action:@selector(multiTouchRecognized:)];
        _gestureRecognizer.delegate = self;
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

    [self installGestureRecognizerIfNeededInWindow:window];
    [self updateGestureRecognizerEnabledState];
}

#pragma mark - Interest

- (BOOL)shouldProcessEvents {
    LAAssertMainQueue();
    LATEventSourceInterestGate *interestGate = self.interestGate;
    return !interestGate || [interestGate isInterestedInFamily:LATEventSourceInterestFamilyMultiTouch];
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
    [LASharedActivator sendEventToListener:event];
    HBLogInfo(@"Classified and dispatched multi-touch event=%@ touchCount=%lu bounds=%@", eventName,
              (unsigned long)touchCount, NSStringFromCGRect(bounds));
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
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
