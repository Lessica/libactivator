//
//  LATBuiltInListenerRegistrant.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInListenerRegistrant.h"

#import "LATEventSource.h"

@interface LATBuiltInListenerContext ()

@property(nonatomic, copy) NSArray<id<LATEventSource>> *eventSources;

@end

@implementation LATBuiltInListenerContext

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource
                springBoardInstanceProvider:(id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
                               eventSources:(NSArray<id<LATEventSource>> *)eventSources {
    NSParameterAssert(applicationLauncher);
    NSParameterAssert(runtimeStateSource);
    NSParameterAssert(eventSources);

    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
        _runtimeStateSource = runtimeStateSource;
        _springBoardInstanceProvider = springBoardInstanceProvider;
        _eventSources = [eventSources copy];
    }
    return self;
}

- (id)eventSourceConformingToProtocol:(Protocol *)protocol {
    if (!protocol) {
        return nil;
    }
    for (id<LATEventSource> eventSource in self.eventSources) {
        if ([eventSource conformsToProtocol:protocol]) {
            return eventSource;
        }
    }
    return nil;
}

@end
