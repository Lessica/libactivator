//
//  LATEventSourceDefinitionBinding.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceDefinitionBinding.h"

#import "LATEventSourceRegistry.h"

@interface LATEventSourceDefinitionBinding ()
@property(nonatomic, strong, readwrite) id<LATEventDefinitionProvider> provider;
@property(nonatomic, strong, readwrite) id<LATEventSourceDefinitionConsumer> eventSource;
@end

@implementation LATEventSourceDefinitionBinding

- (instancetype)initWithProvider:(id<LATEventDefinitionProvider>)provider
                     eventSource:(id<LATEventSourceDefinitionConsumer>)eventSource {
    NSParameterAssert(provider);
    NSParameterAssert(eventSource);

    self = [super init];
    if (self) {
        _provider = provider;
        _eventSource = eventSource;
    }
    return self;
}

- (BOOL)applyEventNames:(NSSet<NSString *> *)eventNames
     previousEventNames:(__unused NSSet<NSString *> *)previousEventNames
    eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry {
    NSSet<NSString *> *previousConfiguredEventNames = self.eventSource.configuredEventNames;
    [self.eventSource updateConfiguredEventNames:eventNames];
    if ([eventSourceRegistry reloadEventNamesForEventSource:self.eventSource]) {
        return YES;
    }

    [self.eventSource updateConfiguredEventNames:previousConfiguredEventNames];
    [eventSourceRegistry reloadEventNamesForEventSource:self.eventSource];
    return NO;
}

@end
