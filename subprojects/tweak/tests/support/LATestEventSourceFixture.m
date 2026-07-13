//
//  LATestEventSourceFixture.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSourceFixture.h"

#import "LAActivator+Private.h"
#import "LATEventDispatcher.h"

@interface LATestEventSourceRuntimeLockStateUpdater : NSObject <LATRuntimeLockStateUpdating>
@end

@implementation LATestEventSourceRuntimeLockStateUpdater

- (void)noteUILocked:(__unused BOOL)uiLocked {
}

@end

@interface LATestEventSourceFixture ()

@property(nonatomic, strong) LAActivator *activator;

@end

@implementation LATestEventSourceFixture

- (instancetype)initWithActivator:(LAActivator *)activator {
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
    }
    return self;
}

- (LATEventSourceContext *)contextWithPreviousEventSources:(NSArray<id<LATEventSource>> *)previousEventSources {
    return
        [[LATEventSourceContext alloc] initWithActivator:self.activator
                                         eventDispatcher:[[LATEventDispatcher alloc] initWithActivator:self.activator]
                                 runtimeLockStateUpdater:[[LATestEventSourceRuntimeLockStateUpdater alloc] init]
                                    previousEventSources:previousEventSources];
}

- (__kindof NSObject<LATEventSource> *)interestedEventSourceOfClass:(Class<LATEventSource>)eventSourceClass
                                               previousEventSources:
                                                   (NSArray<id<LATEventSource>> *)previousEventSources {
    NSObject<LATEventSource> *eventSource = [[(Class)eventSourceClass alloc]
        initWithEventSourceContext:[self contextWithPreviousEventSources:previousEventSources]];
    if (eventSource.interestPolicy != LATEventSourceInterestPolicyAssignedInCurrentMode) {
        return eventSource;
    }

    NSSet<NSString *> *interestEventNames = eventSource.eventNames;
    if ([eventSource respondsToSelector:@selector(interestEventNames)]) {
        interestEventNames = eventSource.interestEventNames;
    }
    if ([eventSource respondsToSelector:@selector(eventSourceInterestedEventNamesDidChange:)]) {
        [eventSource eventSourceInterestedEventNamesDidChange:interestEventNames];
    }
    if ([eventSource respondsToSelector:@selector(eventSourceInterestDidChange:)]) {
        [eventSource eventSourceInterestDidChange:YES];
    }
    return eventSource;
}

- (NSUInteger)dispatchCountForEventName:(NSString *)eventName {
    return [self.activator.la_eventDispatchCounts[eventName] unsignedIntegerValue];
}

@end
