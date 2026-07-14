//
//  LATGestureBarEventSource.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATGestureBarEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

static CGFloat const LATGestureBarEventSourceBottomRegionHeight = 30.0;

@interface LATGestureBarEventSource ()

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, strong) NSHashTable<UITapGestureRecognizer *> *knownRecognizers;
@property(nonatomic, strong) NSHashTable<UITapGestureRecognizer *> *attachedRecognizers;

@end

@implementation LATGestureBarEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    if (![context.eventDispatcher hasEventDefinitionWithName:LAEventNameGestureBarTapDouble]) {
        return nil;
    }
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
        _knownRecognizers = [NSHashTable weakObjectsHashTable];
        _attachedRecognizers = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (NSString *)eventSourceIdentifier {
    return @"gesture-bar";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithObject:LAEventNameGestureBarTapDouble];
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
    for (UITapGestureRecognizer *recognizer in self.knownRecognizers.allObjects) {
        [self attachToRecognizerIfNeeded:recognizer];
    }
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    for (UITapGestureRecognizer *recognizer in self.attachedRecognizers.allObjects) {
        [recognizer removeTarget:self action:@selector(gestureBarDoubleTapRecognized:)];
    }
    [self.attachedRecognizers removeAllObjects];
    [self.knownRecognizers removeAllObjects];
}

#pragma mark - Recognizer Attachment

- (void)noteGestureBarDoubleTapRecognizerDidLoad:(UITapGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    if (!recognizer || self.isInvalidated) {
        return;
    }

    [self.knownRecognizers addObject:recognizer];
    if (self.isStarted) {
        [self attachToRecognizerIfNeeded:recognizer];
    }
}

- (void)attachToRecognizerIfNeeded:(UITapGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    if ([self.attachedRecognizers containsObject:recognizer]) {
        return;
    }

    [recognizer addTarget:self action:@selector(gestureBarDoubleTapRecognized:)];
    [self.attachedRecognizers addObject:recognizer];
}

#pragma mark - Recognition

- (void)gestureBarDoubleTapRecognized:(UITapGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    UIView *view = recognizer.view;
    if (!view) {
        return;
    }
    [self handleTapState:recognizer.state location:[recognizer locationInView:view] bounds:view.bounds];
}

- (BOOL)handleTapState:(UIGestureRecognizerState)state location:(CGPoint)location bounds:(CGRect)bounds {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated || state != UIGestureRecognizerStateEnded ||
        location.y < CGRectGetMaxY(bounds) - LATGestureBarEventSourceBottomRegionHeight) {
        return NO;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:LAEventNameGestureBarTapDouble mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
    HBLogInfo(@"Dispatched gesture bar double-tap event mode=%@", eventMode);
    return YES;
}

#if DEBUG
#pragma mark - Testing Hooks

- (BOOL)la_testingHandleTapState:(UIGestureRecognizerState)state location:(CGPoint)location bounds:(CGRect)bounds {
    return [self handleTapState:state location:location bounds:bounds];
}

- (NSUInteger)la_testingKnownRecognizerCount {
    return self.knownRecognizers.count;
}

- (BOOL)la_testingIsAttachedToRecognizer:(UITapGestureRecognizer *)recognizer {
    return [self.attachedRecognizers containsObject:recognizer];
}
#endif

@end
