//
//  LATEventSourceModule.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceModule.h"

@interface LATEventSourceModuleContext ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *servicesByProtocolName;
@end

@implementation LATEventSourceModuleContext

- (instancetype)initWithActivator:(LAActivator *)activator
                  eventDispatcher:(id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying,
                                      LATEventDefinitionQuerying>)eventDispatcher
          runtimeLockStateUpdater:(id<LATRuntimeLockStateUpdating>)runtimeLockStateUpdater {
    NSParameterAssert(activator);
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(runtimeLockStateUpdater);

    self = [super init];
    if (self) {
        _activator = activator;
        _eventDispatcher = eventDispatcher;
        _runtimeLockStateUpdater = runtimeLockStateUpdater;
        _servicesByProtocolName = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)serviceForProtocol:(Protocol *)protocol {
    if (!protocol) {
        return nil;
    }
    return self.servicesByProtocolName[LATEventSourceServiceKey(protocol)];
}

- (BOOL)registerService:(id)service forProtocolName:(NSString *)protocolName {
    if (!service || protocolName.length == 0 || self.servicesByProtocolName[protocolName]) {
        return NO;
    }
    self.servicesByProtocolName[protocolName] = service;
    return YES;
}

- (void)removeServiceForProtocolName:(NSString *)protocolName {
    if (protocolName.length > 0) {
        [self.servicesByProtocolName removeObjectForKey:protocolName];
    }
}

@end

@implementation LATEventSourceModuleResult

- (instancetype)init {
    return [self initWithEventSources:@[] definitionProviders:@[] definitionBindings:@[] exportedServices:@{}];
}

- (instancetype)initWithEventSources:(NSArray<id<LATEventSource>> *)eventSources
                 definitionProviders:(NSArray<id<LATEventDefinitionProvider>> *)definitionProviders
                  definitionBindings:(NSArray<LATEventSourceDefinitionBinding *> *)definitionBindings
                    exportedServices:(NSDictionary<NSString *, id> *)exportedServices {
    NSParameterAssert(eventSources);
    NSParameterAssert(definitionProviders);
    NSParameterAssert(definitionBindings);
    NSParameterAssert(exportedServices);

    self = [super init];
    if (self) {
        _eventSources = [eventSources copy];
        _definitionProviders = [definitionProviders copy];
        _definitionBindings = [definitionBindings copy];
        _exportedServices = [exportedServices copy];
    }
    return self;
}

@end
