//
//  LATMotionEventSource.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMotionEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>

@interface LATMotionEventSource ()

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

@end

@implementation LATMotionEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (NSString *)eventSourceIdentifier {
    return @"motion";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithObject:LAEventNameMotionShake];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.isStarted || self.isInvalidated) {
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
}

#pragma mark - Motion

- (void)noteMotionEnded:(UIEventSubtype)motion {
    LAAssertMainQueue();
    [self handleMotionEnded:motion];
}

- (BOOL)handleMotionEnded:(UIEventSubtype)motion {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated || motion != UIEventSubtypeMotionShake) {
        return NO;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:LAEventNameMotionShake mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
    return YES;
}

#if DEBUG
#pragma mark - Testing Hooks

- (BOOL)la_testingNoteMotionEnded:(UIEventSubtype)motion {
    return [self handleMotionEnded:motion];
}
#endif

@end
