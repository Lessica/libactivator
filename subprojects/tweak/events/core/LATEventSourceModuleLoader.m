//
//  LATEventSourceModuleLoader.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceModuleLoader.h"

#import "LAQueueAssertions.h"

#import <HBLog.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

static NSString *const LATEventSourceModuleLoaderErrorDomain = @"LATEventSourceModuleLoaderErrorDomain";

@interface LATEventSourceModuleLoader ()

@property(nonatomic, copy, nullable) NSArray<Class> *moduleClassesOverride;
@property(nonatomic, strong) LATEventSourceModuleContext *context;
@property(nonatomic, strong) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, strong) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, copy, readwrite) NSArray<Class> *orderedModuleClasses;
@property(nonatomic, copy, readwrite) NSArray<id<LATEventSource>> *eventSources;
@property(nonatomic, copy, readwrite) NSArray<id<LATEventDefinitionProvider>> *definitionProviders;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, LATEventSourceDefinitionBinding *> *bindingsByProvider;
@property(nonatomic, assign, readwrite, getter=isLoaded) BOOL loaded;
@property(nonatomic, assign) BOOL loadFailed;

@end

@implementation LATEventSourceModuleLoader

- (instancetype)initWithContext:(LATEventSourceModuleContext *)context
            eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry
        eventDefinitionRegistry:(LATEventDefinitionRegistry *)eventDefinitionRegistry {
    return [self initWithModuleClasses:nil
                               context:context
                   eventSourceRegistry:eventSourceRegistry
               eventDefinitionRegistry:eventDefinitionRegistry];
}

- (instancetype)initWithModuleClasses:(nullable NSArray<Class> *)moduleClasses
                              context:(LATEventSourceModuleContext *)context
                  eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry
              eventDefinitionRegistry:(LATEventDefinitionRegistry *)eventDefinitionRegistry {
    LAAssertMainQueue();
    NSParameterAssert(context);
    NSParameterAssert(eventSourceRegistry);
    NSParameterAssert(eventDefinitionRegistry);

    self = [super init];
    if (self) {
        _moduleClassesOverride = [moduleClasses copy];
        _context = context;
        _eventSourceRegistry = eventSourceRegistry;
        _eventDefinitionRegistry = eventDefinitionRegistry;
        _orderedModuleClasses = @[];
        _eventSources = @[];
        _definitionProviders = @[];
        _bindingsByProvider = [[NSMapTable alloc]
            initWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                  valueOptions:NSPointerFunctionsStrongMemory
                      capacity:0];
    }
    return self;
}

- (void)setError:(NSError **)error description:(NSString *)description {
    if (error) {
        *error = [NSError errorWithDomain:LATEventSourceModuleLoaderErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey : description ?: @"Unknown module loader error"}];
    }
}

- (NSArray<Class> *)discoverModuleClassesWithError:(NSError **)error {
    const char *imageName = class_getImageName(LATEventSourceModuleLoader.class);
    if (!imageName) {
        [self setError:error description:@"Unable to identify the Activator tweak image"];
        return nil;
    }

    unsigned int classCount = 0;
    const char **classNames = objc_copyClassNamesForImage(imageName, &classCount);
    if (!classNames) {
        [self setError:error description:@"Unable to enumerate classes in the Activator tweak image"];
        return nil;
    }

    NSMutableArray<Class> *moduleClasses = [[NSMutableArray alloc] init];
    for (unsigned int index = 0; index < classCount; index++) {
        Class candidateClass = objc_lookUpClass(classNames[index]);
        const char *candidateImageName = candidateClass ? class_getImageName(candidateClass) : NULL;
        if (!candidateClass || !candidateImageName || strcmp(candidateImageName, imageName) != 0 ||
            !class_conformsToProtocol(candidateClass, @protocol(LATEventSourceModule))) {
            continue;
        }
        [moduleClasses addObject:candidateClass];
    }
    free(classNames);
    return [moduleClasses copy];
}

- (NSArray<Class> *)orderedSupportedModuleClassesFromClasses:(NSArray<Class> *)moduleClasses error:(NSError **)error {
    NSMutableDictionary<NSString *, Class> *classesByIdentifier = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSNumber *> *prioritiesByIdentifier = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *dependenciesByIdentifier =
        [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *requiredDependenciesByIdentifier =
        [[NSMutableDictionary alloc] init];
    NSMutableSet<NSString *> *supportedIdentifiers = [[NSMutableSet alloc] init];

    for (Class candidateClass in moduleClasses) {
        if (!class_conformsToProtocol(candidateClass, @protocol(LATEventSourceModule)) ||
            ![candidateClass respondsToSelector:@selector(eventSourceModuleIdentifier)] ||
            ![candidateClass respondsToSelector:@selector(eventSourceModulePriority)] ||
            ![candidateClass respondsToSelector:@selector(loadWithContext:error:)]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Class %@ does not satisfy the Event Source module contract",
                                                       NSStringFromClass(candidateClass)]];
            return nil;
        }

        Class<LATEventSourceModule> moduleClass = (Class<LATEventSourceModule>)candidateClass;
        NSString *identifier = [moduleClass eventSourceModuleIdentifier];
        if (![identifier isKindOfClass:NSString.class] || identifier.length == 0) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ has an empty identifier",
                                                       NSStringFromClass(candidateClass)]];
            return nil;
        }
        if (classesByIdentifier[identifier]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Duplicate Event Source module identifier %@", identifier]];
            return nil;
        }

        NSArray<NSString *> *dependencies = @[];
        if ([moduleClass respondsToSelector:@selector(requiredEventSourceModuleIdentifiers)]) {
            id declaredDependencies = [moduleClass requiredEventSourceModuleIdentifiers];
            if (declaredDependencies && ![declaredDependencies isKindOfClass:NSArray.class]) {
                [self setError:error
                    description:[NSString stringWithFormat:@"Event Source module %@ has an invalid dependency list",
                                                           identifier]];
                return nil;
            }
            dependencies = declaredDependencies ?: @[];
        }
        NSMutableSet<NSString *> *normalizedDependencies = [[NSMutableSet alloc] init];
        for (id dependency in dependencies) {
            if (![dependency isKindOfClass:NSString.class] || [dependency length] == 0) {
                [self setError:error
                    description:[NSString
                                    stringWithFormat:@"Event Source module %@ has an invalid dependency", identifier]];
                return nil;
            }
            [normalizedDependencies addObject:dependency];
        }

        NSArray<NSString *> *orderingDependencies = @[];
        if ([moduleClass respondsToSelector:@selector(eventSourceModuleOrderingDependencies)]) {
            id declaredDependencies = [moduleClass eventSourceModuleOrderingDependencies];
            if (declaredDependencies && ![declaredDependencies isKindOfClass:NSArray.class]) {
                [self setError:error
                    description:[NSString
                                    stringWithFormat:@"Event Source module %@ has an invalid ordering dependency list",
                                                     identifier]];
                return nil;
            }
            orderingDependencies = declaredDependencies ?: @[];
        }
        NSMutableSet<NSString *> *normalizedOrderingDependencies = [[NSMutableSet alloc] init];
        for (id dependency in orderingDependencies) {
            if (![dependency isKindOfClass:NSString.class] || [dependency length] == 0) {
                [self setError:error
                    description:[NSString stringWithFormat:@"Event Source module %@ has an invalid ordering dependency",
                                                           identifier]];
                return nil;
            }
            [normalizedOrderingDependencies addObject:dependency];
        }

        classesByIdentifier[identifier] = candidateClass;
        prioritiesByIdentifier[identifier] = @([moduleClass eventSourceModulePriority]);
        requiredDependenciesByIdentifier[identifier] =
            [[normalizedDependencies allObjects] sortedArrayUsingSelector:@selector(compare:)];
        [normalizedDependencies unionSet:normalizedOrderingDependencies];
        dependenciesByIdentifier[identifier] =
            [[normalizedDependencies allObjects] sortedArrayUsingSelector:@selector(compare:)];

        BOOL supported = YES;
        if ([moduleClass respondsToSelector:@selector(isSupportedWithContext:)]) {
            supported = [moduleClass isSupportedWithContext:self.context];
        }
        if (supported) {
            [supportedIdentifiers addObject:identifier];
        }
    }

    for (NSString *identifier in supportedIdentifiers) {
        for (NSString *dependency in dependenciesByIdentifier[identifier]) {
            if (!classesByIdentifier[dependency]) {
                [self setError:error
                    description:[NSString stringWithFormat:@"Event Source module %@ references unavailable module %@",
                                                           identifier, dependency]];
                return nil;
            }
        }
        for (NSString *dependency in requiredDependenciesByIdentifier[identifier]) {
            if (![supportedIdentifiers containsObject:dependency]) {
                [self setError:error
                    description:[NSString stringWithFormat:@"Event Source module %@ requires unavailable module %@",
                                                           identifier, dependency]];
                return nil;
            }
        }
    }

    NSMutableArray<Class> *orderedClasses = [[NSMutableArray alloc] initWithCapacity:supportedIdentifiers.count];
    NSMutableSet<NSString *> *resolvedIdentifiers = [[NSMutableSet alloc] init];
    NSMutableSet<NSString *> *pendingIdentifiers = [supportedIdentifiers mutableCopy];
    while (pendingIdentifiers.count > 0) {
        NSMutableArray<NSString *> *readyIdentifiers = [[NSMutableArray alloc] init];
        for (NSString *identifier in pendingIdentifiers) {
            NSMutableSet<NSString *> *dependencies = [NSMutableSet setWithArray:dependenciesByIdentifier[identifier]];
            [dependencies intersectSet:supportedIdentifiers];
            if ([dependencies isSubsetOfSet:resolvedIdentifiers]) {
                [readyIdentifiers addObject:identifier];
            }
        }
        if (readyIdentifiers.count == 0) {
            [self setError:error description:@"Event Source module dependency graph contains a cycle"];
            return nil;
        }

        [readyIdentifiers sortUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
            NSComparisonResult priorityResult = [prioritiesByIdentifier[left] compare:prioritiesByIdentifier[right]];
            return priorityResult == NSOrderedSame ? [left compare:right] : priorityResult;
        }];
        NSString *nextIdentifier = readyIdentifiers.firstObject;
        [orderedClasses addObject:classesByIdentifier[nextIdentifier]];
        [resolvedIdentifiers addObject:nextIdentifier];
        [pendingIdentifiers removeObject:nextIdentifier];
    }
    return [orderedClasses copy];
}

- (BOOL)validateModuleResult:(LATEventSourceModuleResult *)result
                 moduleClass:(Class<LATEventSourceModule>)moduleClass
                       error:(NSError **)error {
    if (![result isKindOfClass:LATEventSourceModuleResult.class]) {
        [self setError:error
            description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid result",
                                                   [moduleClass eventSourceModuleIdentifier]]];
        return NO;
    }
    if (![result.eventSources isKindOfClass:NSArray.class] ||
        ![result.definitionProviders isKindOfClass:NSArray.class] ||
        ![result.definitionBindings isKindOfClass:NSArray.class] ||
        ![result.exportedServices isKindOfClass:NSDictionary.class]) {
        [self setError:error
            description:[NSString stringWithFormat:@"Event Source module %@ returned malformed result containers",
                                                   [moduleClass eventSourceModuleIdentifier]]];
        return NO;
    }
    for (id eventSource in result.eventSources) {
        if (![eventSource conformsToProtocol:@protocol(LATEventSource)]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid source",
                                                       [moduleClass eventSourceModuleIdentifier]]];
            return NO;
        }
    }
    for (id provider in result.definitionProviders) {
        if (![provider conformsToProtocol:@protocol(LATEventDefinitionProvider)]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid provider",
                                                       [moduleClass eventSourceModuleIdentifier]]];
            return NO;
        }
    }
    for (id binding in result.definitionBindings) {
        if (![binding isKindOfClass:LATEventSourceDefinitionBinding.class]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid binding",
                                                       [moduleClass eventSourceModuleIdentifier]]];
            return NO;
        }
    }
    for (id protocolName in result.exportedServices) {
        if (![protocolName isKindOfClass:NSString.class]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid service export",
                                                       [moduleClass eventSourceModuleIdentifier]]];
            return NO;
        }
        NSString *serviceProtocolName = protocolName;
        id service = result.exportedServices[serviceProtocolName];
        Protocol *protocol = NSProtocolFromString(serviceProtocolName);
        if (serviceProtocolName.length == 0 || !protocol || !service || ![service conformsToProtocol:protocol]) {
            [self setError:error
                description:[NSString stringWithFormat:@"Event Source module %@ returned an invalid service export",
                                                       [moduleClass eventSourceModuleIdentifier]]];
            return NO;
        }
    }
    return YES;
}

- (void)rollbackRegisteredProviders:(NSArray<id<LATEventDefinitionProvider>> *)registeredProviders
             registeredEventSources:(NSArray<id<LATEventSource>> *)registeredEventSources
            constructedEventSources:(NSArray<id<LATEventSource>> *)constructedEventSources
                       serviceNames:(NSArray<NSString *> *)serviceNames {
    BOOL providerRollbackFailed = NO;
    for (id<LATEventDefinitionProvider> provider in registeredProviders.reverseObjectEnumerator) {
        if (![self.eventDefinitionRegistry unregisterProvider:provider]) {
            providerRollbackFailed = YES;
        }
    }
    if (providerRollbackFailed) {
        HBLogError(@"Unable to roll back all Event Source definition providers; invalidating the definition registry");
        [self.eventDefinitionRegistry invalidate];
    }
    if (self.eventDefinitionRegistry.providers.count == 0 && self.eventDefinitionRegistry.delegate == self) {
        self.eventDefinitionRegistry.delegate = nil;
    }

    NSHashTable<id<LATEventSource>> *registeredIdentities =
        [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (id<LATEventSource> eventSource in registeredEventSources) {
        [registeredIdentities addObject:eventSource];
    }
    BOOL sourceRollbackFailed = NO;
    for (id<LATEventSource> eventSource in registeredEventSources.reverseObjectEnumerator) {
        if (![self.eventSourceRegistry unregisterEventSource:eventSource]) {
            sourceRollbackFailed = YES;
        }
    }
    if (sourceRollbackFailed) {
        HBLogError(@"Unable to roll back all Event Sources; invalidating the source registry");
        [self.eventSourceRegistry invalidate];
    }
    NSHashTable<id<LATEventSource>> *invalidatedIdentities =
        [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (id<LATEventSource> eventSource in constructedEventSources.reverseObjectEnumerator) {
        if (![registeredIdentities containsObject:eventSource] && ![invalidatedIdentities containsObject:eventSource]) {
            [eventSource invalidate];
            [invalidatedIdentities addObject:eventSource];
        }
    }
    for (NSString *serviceName in serviceNames.reverseObjectEnumerator) {
        [self.context removeServiceForProtocolName:serviceName];
    }
    [self.bindingsByProvider removeAllObjects];
}

- (BOOL)loadModules {
    LAAssertMainQueue();
    if (self.loaded) {
        return YES;
    }
    if (self.loadFailed) {
        return NO;
    }
    if (self.eventSourceRegistry.isStarted || self.eventSourceRegistry.isInvalidated ||
        self.eventSourceRegistry.eventSources.count > 0 || self.eventDefinitionRegistry.isInvalidated ||
        self.eventDefinitionRegistry.providers.count > 0 || self.eventDefinitionRegistry.delegate) {
        HBLogError(@"Event Source modules require fresh source and definition registries");
        self.loadFailed = YES;
        return NO;
    }

    NSError *error = nil;
    NSArray<Class> *candidateClasses = self.moduleClassesOverride ?: [self discoverModuleClassesWithError:&error];
    NSArray<Class> *orderedClasses =
        candidateClasses ? [self orderedSupportedModuleClassesFromClasses:candidateClasses error:&error] : nil;
    if (!orderedClasses) {
        HBLogError(@"Unable to resolve Event Source modules: %@", error.localizedDescription ?: @"unknown error");
        self.loadFailed = YES;
        return NO;
    }

    NSMutableArray<id<LATEventSource>> *eventSources = [[NSMutableArray alloc] init];
    NSMutableArray<id<LATEventDefinitionProvider>> *definitionProviders = [[NSMutableArray alloc] init];
    NSMutableArray<LATEventSourceDefinitionBinding *> *definitionBindings = [[NSMutableArray alloc] init];
    NSMutableArray<NSString *> *serviceNames = [[NSMutableArray alloc] init];
    for (Class candidateClass in orderedClasses) {
        Class<LATEventSourceModule> moduleClass = (Class<LATEventSourceModule>)candidateClass;
        LATEventSourceModuleResult *result = [moduleClass loadWithContext:self.context error:&error];
        if (![self validateModuleResult:result moduleClass:moduleClass error:&error]) {
            HBLogError(@"Unable to construct Event Source module %@: %@", [moduleClass eventSourceModuleIdentifier],
                       error.localizedDescription ?: @"unknown error");
            NSMutableArray<id<LATEventSource>> *constructedEventSources = [eventSources mutableCopy];
            if ([result isKindOfClass:LATEventSourceModuleResult.class] &&
                [result.eventSources isKindOfClass:NSArray.class]) {
                for (id eventSource in result.eventSources) {
                    if ([eventSource conformsToProtocol:@protocol(LATEventSource)]) {
                        [constructedEventSources addObject:eventSource];
                    }
                }
            }
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:@[]
                      constructedEventSources:constructedEventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [eventSources addObjectsFromArray:result.eventSources];
        [definitionProviders addObjectsFromArray:result.definitionProviders];
        [definitionBindings addObjectsFromArray:result.definitionBindings];
        for (NSString *protocolName in result.exportedServices) {
            if (![self.context registerService:result.exportedServices[protocolName] forProtocolName:protocolName]) {
                HBLogError(@"Unable to construct Event Source module %@ because service %@ is already exported",
                           [moduleClass eventSourceModuleIdentifier], protocolName);
                [self rollbackRegisteredProviders:@[]
                           registeredEventSources:@[]
                          constructedEventSources:eventSources
                                     serviceNames:serviceNames];
                self.loadFailed = YES;
                return NO;
            }
            [serviceNames addObject:protocolName];
        }
    }

    NSHashTable *eventSourceIdentities = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSHashTable *providerIdentities = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (id<LATEventSource> eventSource in eventSources) {
        if ([eventSourceIdentities containsObject:eventSource]) {
            HBLogError(@"An Event Source module returned the same source object more than once");
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:@[]
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [eventSourceIdentities addObject:eventSource];
    }
    for (id<LATEventDefinitionProvider> provider in definitionProviders) {
        if ([providerIdentities containsObject:provider]) {
            HBLogError(@"An Event Source module returned the same definition provider more than once");
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:@[]
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [providerIdentities addObject:provider];
    }
    NSHashTable *boundEventSourceIdentities =
        [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (LATEventSourceDefinitionBinding *binding in definitionBindings) {
        if (![eventSourceIdentities containsObject:binding.eventSource] ||
            ![providerIdentities containsObject:binding.provider] ||
            [self.bindingsByProvider objectForKey:binding.provider] ||
            [boundEventSourceIdentities containsObject:binding.eventSource]) {
            HBLogError(@"An Event Source module returned an inconsistent definition binding");
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:@[]
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [self.bindingsByProvider setObject:binding forKey:binding.provider];
        [boundEventSourceIdentities addObject:binding.eventSource];
    }

    NSMutableArray<id<LATEventSource>> *registeredEventSources = [[NSMutableArray alloc] init];
    for (id<LATEventSource> eventSource in eventSources) {
        if (![self.eventSourceRegistry registerEventSource:eventSource]) {
            HBLogError(@"Unable to register Event Source %@", eventSource.eventSourceIdentifier);
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:registeredEventSources
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [registeredEventSources addObject:eventSource];
    }

    if (definitionProviders.count > 0) {
        if (self.eventDefinitionRegistry.delegate && self.eventDefinitionRegistry.delegate != self) {
            HBLogError(@"Unable to register Event Source modules because the definition registry has another delegate");
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:registeredEventSources
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        self.eventDefinitionRegistry.delegate = self;
        if (self.eventDefinitionRegistry.delegate != self) {
            HBLogError(@"Unable to install the Event Source definition composition delegate");
            [self rollbackRegisteredProviders:@[]
                       registeredEventSources:registeredEventSources
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
    }

    NSMutableArray<id<LATEventDefinitionProvider>> *registeredProviders = [[NSMutableArray alloc] init];
    for (id<LATEventDefinitionProvider> provider in definitionProviders) {
        if (![self.eventDefinitionRegistry registerProvider:provider]) {
            HBLogError(@"Unable to register Event Source definition provider %@",
                       provider.eventDefinitionProviderIdentifier);
            [self rollbackRegisteredProviders:registeredProviders
                       registeredEventSources:registeredEventSources
                      constructedEventSources:eventSources
                                 serviceNames:serviceNames];
            self.loadFailed = YES;
            return NO;
        }
        [registeredProviders addObject:provider];
    }

    self.orderedModuleClasses = orderedClasses;
    self.eventSources = [eventSources copy];
    self.definitionProviders = [definitionProviders copy];
    self.loaded = YES;
    return YES;
}

- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol {
    LAAssertMainQueue();
    if (!protocol || !self.loaded) {
        return @[];
    }
    NSMutableArray<id> *matchingEventSources = [[NSMutableArray alloc] init];
    for (id<LATEventSource> eventSource in self.eventSources) {
        if ([eventSource conformsToProtocol:protocol]) {
            [matchingEventSources addObject:eventSource];
        }
    }
    return [matchingEventSources copy];
}

- (id)serviceForProtocol:(Protocol *)protocol {
    LAAssertMainQueue();
    return self.loaded ? [self.context serviceForProtocol:protocol] : nil;
}

- (BOOL)eventDefinitionRegistry:(__unused LATEventDefinitionRegistry *)registry
                applyEventNames:(NSSet<NSString *> *)eventNames
             previousEventNames:(NSSet<NSString *> *)previousEventNames
                    forProvider:(id<LATEventDefinitionProvider>)provider {
    LATEventSourceDefinitionBinding *binding = [self.bindingsByProvider objectForKey:provider];
    if (!binding) {
        return YES;
    }
    return [binding applyEventNames:eventNames
                 previousEventNames:previousEventNames
                eventSourceRegistry:self.eventSourceRegistry];
}

@end
