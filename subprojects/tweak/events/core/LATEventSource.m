//
//  LATEventSource.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSource.h"

@interface LATEventSourceContext ()

@property(nonatomic, copy) NSArray<id<LATEventSource>> *previousEventSources;

@end

@implementation LATEventSourceContext

- (instancetype)initWithActivator:(LAActivator *)activator
                  eventDispatcher:(id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying,
                                      LATEventDefinitionQuerying>)eventDispatcher
          runtimeLockStateUpdater:(id<LATRuntimeLockStateUpdating>)runtimeLockStateUpdater
             previousEventSources:(NSArray<id<LATEventSource>> *)previousEventSources {
    NSParameterAssert(activator);
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(runtimeLockStateUpdater);
    NSParameterAssert(previousEventSources);

    self = [super init];
    if (self) {
        _activator = activator;
        _eventDispatcher = eventDispatcher;
        _runtimeLockStateUpdater = runtimeLockStateUpdater;
        _previousEventSources = [previousEventSources copy];
    }
    return self;
}

- (id)eventSourceConformingToProtocol:(Protocol *)protocol {
    if (!protocol) {
        return nil;
    }
    for (id<LATEventSource> eventSource in self.previousEventSources) {
        if ([eventSource conformsToProtocol:protocol]) {
            return eventSource;
        }
    }
    return nil;
}

@end
