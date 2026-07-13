//
//  LATEventSourceModuleLoader.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDefinitionRegistry.h"
#import "LATEventSourceModule.h"
#import "LATEventSourceRegistry.h"

NS_ASSUME_NONNULL_BEGIN

// All loader access is main-queue confined.
@interface LATEventSourceModuleLoader : NSObject <LATEventDefinitionRegistryDelegate>

@property(nonatomic, copy, readonly) NSArray<Class> *orderedModuleClasses;
@property(nonatomic, copy, readonly) NSArray<id<LATEventSource>> *eventSources;
@property(nonatomic, copy, readonly) NSArray<id<LATEventDefinitionProvider>> *definitionProviders;
@property(nonatomic, assign, readonly, getter=isLoaded) BOOL loaded;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithContext:(LATEventSourceModuleContext *)context
            eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry
        eventDefinitionRegistry:(LATEventDefinitionRegistry *)eventDefinitionRegistry;
- (instancetype)initWithModuleClasses:(nullable NSArray<Class> *)moduleClasses
                              context:(LATEventSourceModuleContext *)context
                  eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry
              eventDefinitionRegistry:(LATEventDefinitionRegistry *)eventDefinitionRegistry NS_DESIGNATED_INITIALIZER;

- (BOOL)loadModules;
- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol;
- (nullable id)serviceForProtocol:(Protocol *)protocol;

@end

NS_ASSUME_NONNULL_END
