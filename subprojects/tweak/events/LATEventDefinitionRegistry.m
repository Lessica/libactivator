//
//  LATEventDefinitionRegistry.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDefinitionRegistry.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

static NSString *const LATEventDefinitionTemplateIdentifierKey = @"Identifier";
static NSString *const LATEventDefinitionCatalogGenerationKey = @"Generation";
static NSString *const LATEventDefinitionCatalogProvidersKey = @"Providers";
static NSString *const LATEventDefinitionCatalogEventNamesKey = @"EventNames";
static NSString *const LATEventDefinitionCatalogTemplatesKey = @"Templates";

@interface LATEventDefinitionRegistry ()

@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) NSMutableArray<id<LATEventDefinitionProvider>> *orderedProviders;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<LATEventDefinitionProvider>> *providersByIdentifier;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<LATEventDefinitionProvider>> *providersByEventName;
@property(nonatomic, strong) NSMapTable<id<LATEventDefinitionProvider>, NSString *> *identifiersByProvider;
@property(nonatomic, strong) NSMapTable<id<LATEventDefinitionProvider>, id<LAEventDataSource>> *dataSourcesByProvider;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, NSSet<NSString *> *> *declaredEventNamesByProvider;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, NSSet<NSString *> *> *activeEventNamesByProvider;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, NSMutableSet<NSString *> *> *ownedEventNamesByProvider;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, NSArray<NSDictionary<NSString *, id> *> *> *templatesByProvider;
@property(nonatomic, assign, readwrite) NSUInteger generation;
@property(nonatomic, assign, readwrite, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, assign) BOOL applyingMutation;
@property(nonatomic, assign) BOOL ownershipReconciliationScheduled;

@end

@implementation LATEventDefinitionRegistry

+ (NSNotificationName)changedNotification {
    return @"LATEventDefinitionRegistryChangedNotification";
}

- (instancetype)initWithActivator:(LAActivator *)activator {
    LAAssertMainQueue();
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
        _orderedProviders = [[NSMutableArray alloc] init];
        _providersByIdentifier = [[NSMutableDictionary alloc] init];
        _providersByEventName = [[NSMutableDictionary alloc] init];

        NSPointerFunctionsOptions providerKeyOptions =
            NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality;
        _identifiersByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                           valueOptions:NSPointerFunctionsStrongMemory
                                                               capacity:0];
        _dataSourcesByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                           valueOptions:NSPointerFunctionsStrongMemory
                                                               capacity:0];
        _declaredEventNamesByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                                  valueOptions:NSPointerFunctionsStrongMemory
                                                                      capacity:0];
        _activeEventNamesByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                                valueOptions:NSPointerFunctionsStrongMemory
                                                                    capacity:0];
        _ownedEventNamesByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                               valueOptions:NSPointerFunctionsStrongMemory
                                                                   capacity:0];
        _templatesByProvider = [[NSMapTable alloc] initWithKeyOptions:providerKeyOptions
                                                         valueOptions:NSPointerFunctionsStrongMemory
                                                             capacity:0];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(eventRegistryDidChange:)
                                                   name:LAActivatorEventRegistryChangedNotification
                                                 object:activator];
    }
    return self;
}

- (void)dealloc {
    if (!self.invalidated) {
        [self invalidate];
    } else {
        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

#pragma mark - Registration

- (void)setDelegate:(id<LATEventDefinitionRegistryDelegate>)delegate {
    LAAssertMainQueue();
    if (_delegate == delegate) {
        return;
    }
    if (self.applyingMutation || self.orderedProviders.count > 0) {
        HBLogWarn(@"Ignoring a dynamic definition composition delegate change while providers are registered");
        return;
    }
    _delegate = delegate;
}

- (BOOL)registerProvider:(id<LATEventDefinitionProvider>)provider {
    LAAssertMainQueue();
    if (self.invalidated || self.applyingMutation || !provider) {
        return NO;
    }
    if (provider.eventDefinitionRegistry && provider.eventDefinitionRegistry != self) {
        HBLogWarn(@"Skipping %@ because it is already attached to another dynamic definition registry",
                  NSStringFromClass(provider.class));
        return NO;
    }

    NSString *identifier = provider.eventDefinitionProviderIdentifier;
    id<LAEventDataSource> dataSource = provider.eventDataSource;
    NSSet<NSString *> *eventNames = [self validatedEventNamesForProvider:provider];
    NSArray<NSDictionary<NSString *, id> *> *templates = [self validatedTemplatesForProvider:provider];
    if (identifier.length == 0 || !dataSource || !eventNames || !templates) {
        HBLogWarn(@"Skipping %@ because its dynamic definition contract is invalid", NSStringFromClass(provider.class));
        return NO;
    }

    NSString *registeredIdentifier = [self.identifiersByProvider objectForKey:provider];
    if (registeredIdentifier) {
        if (![registeredIdentifier isEqualToString:identifier] ||
            [self.dataSourcesByProvider objectForKey:provider] != dataSource ||
            ![[self.templatesByProvider objectForKey:provider] isEqualToArray:templates]) {
            HBLogWarn(@"Dynamic definition provider %@ changed immutable registration metadata", identifier);
            return NO;
        }
        return [self reloadEventNamesForProvider:provider];
    }

    id<LATEventDefinitionProvider> existingProvider = self.providersByIdentifier[identifier];
    if (existingProvider && existingProvider != provider) {
        HBLogWarn(@"Skipping %@ because dynamic definition provider identifier %@ is already registered by %@",
                  NSStringFromClass(provider.class), identifier, NSStringFromClass(existingProvider.class));
        return NO;
    }
    if (![self canActivateEventNames:eventNames forProvider:provider dataSource:dataSource]) {
        return NO;
    }

    self.applyingMutation = YES;
    [self.activator la_beginEventRegistryMutation];
    NSSet<NSString *> *newlyRegisteredEventNames = [self registerMissingEventNames:eventNames dataSource:dataSource];
    if (!newlyRegisteredEventNames) {
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        return NO;
    }

    NSString *identifierSnapshot = [identifier copy];
    self.providersByIdentifier[identifierSnapshot] = provider;
    [self.orderedProviders addObject:provider];
    [self.identifiersByProvider setObject:identifierSnapshot forKey:provider];
    [self.dataSourcesByProvider setObject:dataSource forKey:provider];
    [self.declaredEventNamesByProvider setObject:eventNames forKey:provider];
    [self.activeEventNamesByProvider setObject:eventNames forKey:provider];
    [self.ownedEventNamesByProvider setObject:[newlyRegisteredEventNames mutableCopy] forKey:provider];
    [self.templatesByProvider setObject:templates forKey:provider];
    [self replaceEventNameIndexForProvider:provider previousEventNames:[NSSet set] eventNames:eventNames];
    provider.eventDefinitionRegistry = self;

    BOOL compositionApplied = [self synchronizeEventNames:eventNames
                                       previousEventNames:[NSSet set]
                                              forProvider:provider];
    BOOL providerStateIsStable = compositionApplied && [self provider:provider
                                                           matchesIdentifier:identifierSnapshot
                                                                  dataSource:dataSource
                                                                  eventNames:eventNames
                                                                   templates:templates];
    BOOL ownershipIsStable = providerStateIsStable && [[self eventNamesInSet:eventNames
                                                           ownedByDataSource:dataSource] isEqualToSet:eventNames];
    if (!ownershipIsStable) {
        if (compositionApplied && ![self synchronizeEventNames:[NSSet set]
                                            previousEventNames:eventNames
                                                   forProvider:provider]) {
            HBLogError(@"Unable to roll back acquisition mapping for dynamic definition provider %@",
                       identifierSnapshot);
        }
        provider.eventDefinitionRegistry = nil;
        [self.providersByIdentifier removeObjectForKey:identifierSnapshot];
        [self.orderedProviders removeObjectIdenticalTo:provider];
        [self.identifiersByProvider removeObjectForKey:provider];
        [self.dataSourcesByProvider removeObjectForKey:provider];
        [self.declaredEventNamesByProvider removeObjectForKey:provider];
        [self.activeEventNamesByProvider removeObjectForKey:provider];
        [self.ownedEventNamesByProvider removeObjectForKey:provider];
        [self.templatesByProvider removeObjectForKey:provider];
        [self replaceEventNameIndexForProvider:provider previousEventNames:eventNames eventNames:[NSSet set]];
        [self unregisterEventNames:newlyRegisteredEventNames dataSource:dataSource];
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        return NO;
    }

    [self publishChange];
    [self.activator la_endEventRegistryMutation];
    self.applyingMutation = NO;
    return YES;
}

- (BOOL)unregisterProvider:(id<LATEventDefinitionProvider>)provider {
    LAAssertMainQueue();
    if (self.invalidated || self.applyingMutation || ![self providerIsRegistered:provider]) {
        return NO;
    }

    NSString *identifier = [self.identifiersByProvider objectForKey:provider];
    id<LAEventDataSource> dataSource = [self.dataSourcesByProvider objectForKey:provider];
    NSSet<NSString *> *declaredEventNames = [self.declaredEventNamesByProvider objectForKey:provider] ?: [NSSet set];
    NSSet<NSString *> *activeEventNames = [self.activeEventNamesByProvider objectForKey:provider] ?: [NSSet set];
    NSArray<NSDictionary<NSString *, id> *> *templates = [self.templatesByProvider objectForKey:provider] ?: @[];
    self.applyingMutation = YES;
    [self.activator la_beginEventRegistryMutation];
    if (![self synchronizeEventNames:[NSSet set] previousEventNames:activeEventNames forProvider:provider]) {
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        return NO;
    }
    if (![self provider:provider
            matchesIdentifier:identifier
                   dataSource:dataSource
                   eventNames:declaredEventNames
                    templates:templates]) {
        NSSet<NSString *> *rollbackEventNames = [self eventNamesInSet:declaredEventNames ownedByDataSource:dataSource];
        if (![self synchronizeEventNames:rollbackEventNames previousEventNames:[NSSet set] forProvider:provider]) {
            HBLogError(@"Unable to roll back acquisition mapping while unregistering dynamic definition provider %@",
                       identifier);
        }
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        [self scheduleOwnershipReconciliation];
        return NO;
    }

    NSSet<NSString *> *ownedEventNames = [[self.ownedEventNamesByProvider objectForKey:provider] copy] ?: [NSSet set];
    [self replaceEventNameIndexForProvider:provider previousEventNames:activeEventNames eventNames:[NSSet set]];
    [self.providersByIdentifier removeObjectForKey:identifier];
    [self.orderedProviders removeObjectIdenticalTo:provider];
    [self.identifiersByProvider removeObjectForKey:provider];
    [self.dataSourcesByProvider removeObjectForKey:provider];
    [self.declaredEventNamesByProvider removeObjectForKey:provider];
    [self.activeEventNamesByProvider removeObjectForKey:provider];
    [self.ownedEventNamesByProvider removeObjectForKey:provider];
    [self.templatesByProvider removeObjectForKey:provider];
    provider.eventDefinitionRegistry = nil;
    [self unregisterEventNames:ownedEventNames dataSource:dataSource];
    [self publishChange];
    [self.activator la_endEventRegistryMutation];
    self.applyingMutation = NO;
    return YES;
}

- (BOOL)reloadEventNamesForProvider:(id<LATEventDefinitionProvider>)provider {
    LAAssertMainQueue();
    if (self.invalidated || self.applyingMutation || ![self providerIsRegistered:provider]) {
        return NO;
    }

    NSSet<NSString *> *eventNames = [self validatedEventNamesForProvider:provider];
    if (!eventNames) {
        return NO;
    }
    NSSet<NSString *> *previousDeclaredEventNames =
        [self.declaredEventNamesByProvider objectForKey:provider] ?: [NSSet set];
    if ([eventNames isEqualToSet:previousDeclaredEventNames]) {
        return YES;
    }

    NSString *identifier = [self.identifiersByProvider objectForKey:provider];
    id<LAEventDataSource> dataSource = [self.dataSourcesByProvider objectForKey:provider];
    NSArray<NSDictionary<NSString *, id> *> *templates = [self.templatesByProvider objectForKey:provider] ?: @[];
    NSMutableSet<NSString *> *addedEventNames = [eventNames mutableCopy];
    [addedEventNames minusSet:previousDeclaredEventNames];
    if (![self canActivateEventNames:addedEventNames forProvider:provider dataSource:dataSource]) {
        return NO;
    }

    self.applyingMutation = YES;
    [self.activator la_beginEventRegistryMutation];
    NSSet<NSString *> *newlyRegisteredEventNames = [self registerMissingEventNames:addedEventNames
                                                                        dataSource:dataSource];
    if (!newlyRegisteredEventNames) {
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        return NO;
    }

    NSSet<NSString *> *activeEventNames = [self eventNamesInSet:eventNames ownedByDataSource:dataSource];
    if (![addedEventNames isSubsetOfSet:activeEventNames]) {
        [self unregisterEventNames:newlyRegisteredEventNames dataSource:dataSource];
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        return NO;
    }
    NSSet<NSString *> *previousActiveEventNames =
        [self.activeEventNamesByProvider objectForKey:provider] ?: [NSSet set];
    BOOL compositionApplied = [self synchronizeEventNames:activeEventNames
                                       previousEventNames:previousActiveEventNames
                                              forProvider:provider];
    BOOL providerStateIsStable = compositionApplied && [self provider:provider
                                                           matchesIdentifier:identifier
                                                                  dataSource:dataSource
                                                                  eventNames:eventNames
                                                                   templates:templates];
    BOOL ownershipIsStable = providerStateIsStable && [[self eventNamesInSet:eventNames
                                                           ownedByDataSource:dataSource] isEqualToSet:activeEventNames];
    if (!ownershipIsStable) {
        NSSet<NSString *> *rollbackEventNames = [self eventNamesInSet:previousDeclaredEventNames
                                                    ownedByDataSource:dataSource];
        if (compositionApplied && ![self synchronizeEventNames:rollbackEventNames
                                            previousEventNames:activeEventNames
                                                   forProvider:provider]) {
            HBLogError(@"Unable to roll back acquisition mapping for dynamic definition provider %@", identifier);
        }
        [self unregisterEventNames:newlyRegisteredEventNames dataSource:dataSource];
        [self.activator la_endEventRegistryMutation];
        self.applyingMutation = NO;
        [self scheduleOwnershipReconciliation];
        return NO;
    }

    [self.declaredEventNamesByProvider setObject:eventNames forKey:provider];
    [self.activeEventNamesByProvider setObject:activeEventNames forKey:provider];
    [self replaceEventNameIndexForProvider:provider
                        previousEventNames:previousActiveEventNames
                                eventNames:activeEventNames];
    NSMutableSet<NSString *> *ownedEventNames = [self.ownedEventNamesByProvider objectForKey:provider];
    [ownedEventNames unionSet:newlyRegisteredEventNames];

    NSMutableSet<NSString *> *removedEventNames = [previousDeclaredEventNames mutableCopy];
    [removedEventNames minusSet:eventNames];
    NSMutableSet<NSString *> *ownedRemovedEventNames = [removedEventNames mutableCopy];
    [ownedRemovedEventNames intersectSet:ownedEventNames];
    [self unregisterEventNames:ownedRemovedEventNames dataSource:dataSource];
    [ownedEventNames minusSet:removedEventNames];

    [self publishChange];
    [self.activator la_endEventRegistryMutation];
    self.applyingMutation = NO;
    return YES;
}

#pragma mark - Queries And Mutations

- (NSArray<id<LATEventDefinitionProvider>> *)providers {
    LAAssertMainQueue();
    return [self.orderedProviders copy];
}

- (id<LATEventDefinitionProvider>)providerWithIdentifier:(NSString *)identifier {
    LAAssertMainQueue();
    return identifier.length > 0 ? self.providersByIdentifier[identifier] : nil;
}

- (id<LATEventDefinitionProvider>)providerForEventName:(NSString *)eventName {
    LAAssertMainQueue();
    return eventName.length > 0 ? self.providersByEventName[eventName] : nil;
}

- (NSSet<NSString *> *)activeEventNamesForProvider:(id<LATEventDefinitionProvider>)provider {
    LAAssertMainQueue();
    return [[self.activeEventNamesByProvider objectForKey:provider] copy] ?: [NSSet set];
}

- (NSDictionary<NSString *, id> *)eventCreationCatalog {
    LAAssertMainQueue();
    NSMutableArray<NSDictionary<NSString *, id> *> *providers =
        [[NSMutableArray alloc] initWithCapacity:self.orderedProviders.count];
    for (id<LATEventDefinitionProvider> provider in self.orderedProviders) {
        NSString *identifier = [self.identifiersByProvider objectForKey:provider];
        NSArray<NSString *> *eventNames =
            [[self activeEventNamesForProvider:provider].allObjects sortedArrayUsingSelector:@selector(compare:)];
        NSArray<NSDictionary<NSString *, id> *> *templates = [self.templatesByProvider objectForKey:provider] ?: @[];
        [providers addObject:@{
            LATEventDefinitionTemplateIdentifierKey : identifier,
            LATEventDefinitionCatalogEventNamesKey : eventNames,
            LATEventDefinitionCatalogTemplatesKey : templates,
        }];
    }
    return @{
        LATEventDefinitionCatalogGenerationKey : @(self.generation),
        LATEventDefinitionCatalogProvidersKey : [providers copy],
    };
}

- (NSString *)createEventWithProviderIdentifier:(NSString *)providerIdentifier
                             templateIdentifier:(NSString *)templateIdentifier
                                  configuration:(id)configuration
                             expectedGeneration:(NSUInteger)expectedGeneration {
    LAAssertMainQueue();
    if (self.invalidated || self.applyingMutation || expectedGeneration != self.generation ||
        ![self isPropertyListValue:configuration]) {
        return nil;
    }
    id<LATEventDefinitionProvider> provider = [self providerWithIdentifier:providerIdentifier];
    if (!provider || ![self provider:provider hasTemplateIdentifier:templateIdentifier]) {
        return nil;
    }

    NSString *eventName = [provider createEventWithTemplateIdentifier:templateIdentifier configuration:configuration];
    if (eventName.length == 0 || [self providerWithIdentifier:providerIdentifier] != provider ||
        ![provider.eventDefinitionNames containsObject:eventName] ||
        [self providerForEventName:eventName] != provider ||
        [self.activator eventDataSourceForEventName:eventName] != provider.eventDataSource) {
        return nil;
    }
    return eventName;
}

- (id)configurationForEventName:(NSString *)eventName expectedGeneration:(NSUInteger)expectedGeneration {
    LAAssertMainQueue();
    id<LATEventDefinitionProvider> provider = [self providerForEventName:eventName];
    if (self.invalidated || self.applyingMutation || expectedGeneration != self.generation || !provider) {
        return nil;
    }
    id<LAEventDataSource> dataSource = provider.eventDataSource;
    if ([self.activator eventDataSourceForEventName:eventName] != dataSource) {
        return nil;
    }
    id configuration = [self.activator la_configurationForEventWithName:eventName];
    if (expectedGeneration != self.generation || [self providerForEventName:eventName] != provider ||
        [self.activator eventDataSourceForEventName:eventName] != dataSource) {
        return nil;
    }
    return configuration;
}

- (BOOL)saveConfiguration:(id)configuration
             forEventName:(NSString *)eventName
       expectedGeneration:(NSUInteger)expectedGeneration {
    LAAssertMainQueue();
    id<LATEventDefinitionProvider> provider = [self providerForEventName:eventName];
    if (self.invalidated || self.applyingMutation || expectedGeneration != self.generation || !provider ||
        ![self isPropertyListValue:configuration]) {
        return NO;
    }
    id<LAEventDataSource> dataSource = provider.eventDataSource;
    if ([self.activator eventDataSourceForEventName:eventName] != dataSource ||
        ![self.activator la_saveConfiguration:configuration forEventWithName:eventName]) {
        return NO;
    }
    return expectedGeneration == self.generation && [self providerForEventName:eventName] == provider &&
           [self.activator eventDataSourceForEventName:eventName] == dataSource;
}

- (BOOL)removeEventWithName:(NSString *)eventName expectedGeneration:(NSUInteger)expectedGeneration {
    LAAssertMainQueue();
    id<LATEventDefinitionProvider> provider = [self providerForEventName:eventName];
    if (self.invalidated || self.applyingMutation || expectedGeneration != self.generation || !provider) {
        return NO;
    }
    [self.activator removeEventWithName:eventName];
    return ![provider.eventDefinitionNames containsObject:eventName] &&
           [self providerForEventName:eventName] != provider;
}

#pragma mark - Event Registry Reconciliation

- (void)eventRegistryDidChange:(__unused NSNotification *)notification {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf eventRegistryDidChange:nil];
        });
        return;
    }
    if (self.invalidated) {
        return;
    }
    if (self.applyingMutation) {
        [self scheduleOwnershipReconciliation];
        return;
    }
    [self reconcileDefinitionOwnership];
}

- (void)scheduleOwnershipReconciliation {
    if (self.ownershipReconciliationScheduled || self.invalidated) {
        return;
    }
    self.ownershipReconciliationScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.ownershipReconciliationScheduled = NO;
        [self reconcileDefinitionOwnership];
    });
}

- (void)reconcileDefinitionOwnership {
    LAAssertMainQueue();
    if (self.invalidated || self.applyingMutation) {
        return;
    }

    self.applyingMutation = YES;
    [self.activator la_beginEventRegistryMutation];
    BOOL changed = NO;
    for (id<LATEventDefinitionProvider> provider in [self.orderedProviders copy]) {
        NSString *identifier = [self.identifiersByProvider objectForKey:provider];
        NSSet<NSString *> *declaredEventNames =
            [self.declaredEventNamesByProvider objectForKey:provider] ?: [NSSet set];
        NSSet<NSString *> *previousActiveEventNames =
            [self.activeEventNamesByProvider objectForKey:provider] ?: [NSSet set];
        id<LAEventDataSource> dataSource = [self.dataSourcesByProvider objectForKey:provider];
        NSArray<NSDictionary<NSString *, id> *> *templates = [self.templatesByProvider objectForKey:provider] ?: @[];
        if (![self provider:provider
                matchesIdentifier:identifier
                       dataSource:dataSource
                       eventNames:declaredEventNames
                        templates:templates]) {
            HBLogWarn(@"Skipping ownership reconciliation because dynamic definition provider %@ changed its "
                       "registration contract",
                      identifier);
            continue;
        }

        NSMutableSet<NSString *> *registeredDuringReconciliation = [[NSMutableSet alloc] init];
        for (NSString *eventName in declaredEventNames) {
            id<LAEventDataSource> owner = [self.activator eventDataSourceForEventName:eventName];
            if (!owner && [self.activator la_registerEventDataSourceIfAbsent:dataSource forEventName:eventName]) {
                [registeredDuringReconciliation addObject:eventName];
            }
        }

        NSSet<NSString *> *activeEventNamesSnapshot = [self eventNamesInSet:declaredEventNames
                                                          ownedByDataSource:dataSource];
        if ([activeEventNamesSnapshot isEqualToSet:previousActiveEventNames]) {
            [[self.ownedEventNamesByProvider objectForKey:provider] unionSet:registeredDuringReconciliation];
            continue;
        }
        if (![self synchronizeEventNames:activeEventNamesSnapshot
                      previousEventNames:previousActiveEventNames
                             forProvider:provider]) {
            [self unregisterEventNames:registeredDuringReconciliation dataSource:dataSource];
            HBLogWarn(@"Unable to synchronize reconciled dynamic definitions for provider %@",
                      [self.identifiersByProvider objectForKey:provider]);
            continue;
        }

        BOOL providerStateIsStable = [self provider:provider
                                  matchesIdentifier:identifier
                                         dataSource:dataSource
                                         eventNames:declaredEventNames
                                          templates:templates];
        NSSet<NSString *> *postflightEventNames = [self eventNamesInSet:declaredEventNames
                                                      ownedByDataSource:dataSource];
        if (!providerStateIsStable || ![postflightEventNames isEqualToSet:activeEventNamesSnapshot]) {
            if (![self synchronizeEventNames:postflightEventNames
                          previousEventNames:activeEventNamesSnapshot
                                 forProvider:provider]) {
                HBLogError(@"Unable to roll back reconciled acquisition mapping for dynamic definition provider %@",
                           identifier);
                [self unregisterEventNames:registeredDuringReconciliation dataSource:dataSource];
                [self scheduleOwnershipReconciliation];
                continue;
            }
            activeEventNamesSnapshot = postflightEventNames;
            if (providerStateIsStable) {
                [self scheduleOwnershipReconciliation];
            } else {
                HBLogWarn(@"Dynamic definition provider %@ changed its registration contract during ownership "
                           "reconciliation",
                          identifier);
            }
        }

        [self.activeEventNamesByProvider setObject:activeEventNamesSnapshot forKey:provider];
        [self replaceEventNameIndexForProvider:provider
                            previousEventNames:previousActiveEventNames
                                    eventNames:activeEventNamesSnapshot];
        [[self.ownedEventNamesByProvider objectForKey:provider] unionSet:registeredDuringReconciliation];
        changed = YES;
    }
    if (changed) {
        [self publishChange];
    }
    [self.activator la_endEventRegistryMutation];
    self.applyingMutation = NO;
}

#pragma mark - Lifecycle

- (void)invalidate {
    LAAssertMainQueue();
    if (self.invalidated) {
        return;
    }
    if (self.applyingMutation) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf invalidate];
        });
        return;
    }
    self.invalidated = YES;
    [NSNotificationCenter.defaultCenter removeObserver:self];

    BOOL hadProviders = self.orderedProviders.count > 0;
    self.applyingMutation = YES;
    [self.activator la_beginEventRegistryMutation];
    for (id<LATEventDefinitionProvider> provider in [self.orderedProviders.reverseObjectEnumerator allObjects]) {
        NSSet<NSString *> *activeEventNames = [self.activeEventNamesByProvider objectForKey:provider] ?: [NSSet set];
        [self synchronizeEventNames:[NSSet set] previousEventNames:activeEventNames forProvider:provider];
        id<LAEventDataSource> dataSource = [self.dataSourcesByProvider objectForKey:provider];
        NSSet<NSString *> *ownedEventNames =
            [[self.ownedEventNamesByProvider objectForKey:provider] copy] ?: [NSSet set];
        provider.eventDefinitionRegistry = nil;
        [self unregisterEventNames:ownedEventNames dataSource:dataSource];
    }
    [self.orderedProviders removeAllObjects];
    [self.providersByIdentifier removeAllObjects];
    [self.providersByEventName removeAllObjects];
    [self.identifiersByProvider removeAllObjects];
    [self.dataSourcesByProvider removeAllObjects];
    [self.declaredEventNamesByProvider removeAllObjects];
    [self.activeEventNamesByProvider removeAllObjects];
    [self.ownedEventNamesByProvider removeAllObjects];
    [self.templatesByProvider removeAllObjects];
    if (hadProviders) {
        [self publishChange];
    }
    [self.activator la_endEventRegistryMutation];
    self.applyingMutation = NO;
}

#pragma mark - Helpers

- (BOOL)providerIsRegistered:(id<LATEventDefinitionProvider>)provider {
    NSString *identifier = [self.identifiersByProvider objectForKey:provider];
    return identifier.length > 0 && self.providersByIdentifier[identifier] == provider;
}

- (BOOL)provider:(id<LATEventDefinitionProvider>)provider
    matchesIdentifier:(NSString *)identifier
           dataSource:(id<LAEventDataSource>)dataSource
           eventNames:(NSSet<NSString *> *)eventNames
            templates:(NSArray<NSDictionary<NSString *, id> *> *)templates {
    if (![self providerIsRegistered:provider] || provider.eventDefinitionRegistry != self ||
        self.providersByIdentifier[identifier] != provider ||
        ![[self.identifiersByProvider objectForKey:provider] isEqualToString:identifier] ||
        [self.dataSourcesByProvider objectForKey:provider] != dataSource || provider.eventDataSource != dataSource ||
        ![[self.templatesByProvider objectForKey:provider] isEqualToArray:templates]) {
        return NO;
    }

    NSSet<NSString *> *currentEventNames = [self validatedEventNamesForProvider:provider];
    NSArray<NSDictionary<NSString *, id> *> *currentTemplates = [self validatedTemplatesForProvider:provider];
    return [provider.eventDefinitionProviderIdentifier isEqualToString:identifier] &&
           [currentEventNames isEqualToSet:eventNames] && [currentTemplates isEqualToArray:templates];
}

- (NSSet<NSString *> *)eventNamesInSet:(NSSet<NSString *> *)eventNames
                     ownedByDataSource:(id<LAEventDataSource>)dataSource {
    NSMutableSet<NSString *> *ownedEventNames = [[NSMutableSet alloc] initWithCapacity:eventNames.count];
    for (NSString *eventName in eventNames) {
        if ([self.activator eventDataSourceForEventName:eventName] == dataSource) {
            [ownedEventNames addObject:eventName];
        }
    }
    return [ownedEventNames copy];
}

- (nullable NSSet<NSString *> *)validatedEventNamesForProvider:(id<LATEventDefinitionProvider>)provider {
    NSSet *eventNames = provider.eventDefinitionNames;
    if (![eventNames isKindOfClass:NSSet.class]) {
        return nil;
    }
    NSMutableSet<NSString *> *validatedEventNames = [[NSMutableSet alloc] initWithCapacity:eventNames.count];
    for (id eventName in eventNames) {
        if (![eventName isKindOfClass:NSString.class] || [eventName length] == 0) {
            return nil;
        }
        [validatedEventNames addObject:eventName];
    }
    return [validatedEventNames copy];
}

- (nullable NSArray<NSDictionary<NSString *, id> *> *)validatedTemplatesForProvider:
    (id<LATEventDefinitionProvider>)provider {
    id templates = [self immutablePropertyListSnapshot:provider.eventCreationTemplates];
    if (![templates isKindOfClass:NSArray.class]) {
        return nil;
    }
    NSMutableSet<NSString *> *identifiers = [[NSMutableSet alloc] init];
    for (id template in templates) {
        if (![template isKindOfClass:NSDictionary.class]) {
            return nil;
        }
        NSString *identifier = [template[LATEventDefinitionTemplateIdentifierKey] isKindOfClass:NSString.class]
                                   ? template[LATEventDefinitionTemplateIdentifierKey]
                                   : nil;
        if (identifier.length == 0 || [identifiers containsObject:identifier]) {
            return nil;
        }
        [identifiers addObject:identifier];
    }
    return templates;
}

- (BOOL)provider:(id<LATEventDefinitionProvider>)provider hasTemplateIdentifier:(NSString *)templateIdentifier {
    if (templateIdentifier.length == 0) {
        return NO;
    }
    for (NSDictionary<NSString *, id> *template in [self.templatesByProvider objectForKey:provider]) {
        if ([template[LATEventDefinitionTemplateIdentifierKey] isEqualToString:templateIdentifier]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canActivateEventNames:(NSSet<NSString *> *)eventNames
                  forProvider:(id<LATEventDefinitionProvider>)provider
                   dataSource:(id<LAEventDataSource>)dataSource {
    for (NSString *eventName in eventNames) {
        id<LATEventDefinitionProvider> mappedProvider = self.providersByEventName[eventName];
        if (mappedProvider && mappedProvider != provider) {
            HBLogWarn(@"Dynamic definition %@ is already mapped to provider %@", eventName,
                      [self.identifiersByProvider objectForKey:mappedProvider]);
            return NO;
        }
        id<LAEventDataSource> owner = [self.activator eventDataSourceForEventName:eventName];
        if (owner && owner != dataSource) {
            HBLogWarn(@"Dynamic definition %@ is already owned by %@", eventName, NSStringFromClass(owner.class));
            return NO;
        }
    }
    return YES;
}

- (nullable NSSet<NSString *> *)registerMissingEventNames:(NSSet<NSString *> *)eventNames
                                               dataSource:(id<LAEventDataSource>)dataSource {
    NSMutableSet<NSString *> *registeredEventNames = [[NSMutableSet alloc] init];
    NSArray<NSString *> *orderedEventNames = [eventNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *eventName in orderedEventNames) {
        id<LAEventDataSource> owner = [self.activator eventDataSourceForEventName:eventName];
        if (owner == dataSource) {
            continue;
        }
        if (owner || ![self.activator la_registerEventDataSourceIfAbsent:dataSource forEventName:eventName]) {
            [self unregisterEventNames:registeredEventNames dataSource:dataSource];
            return nil;
        }
        [registeredEventNames addObject:eventName];
    }
    for (NSString *eventName in eventNames) {
        if ([self.activator eventDataSourceForEventName:eventName] != dataSource) {
            [self unregisterEventNames:registeredEventNames dataSource:dataSource];
            return nil;
        }
    }
    return [registeredEventNames copy];
}

- (void)unregisterEventNames:(NSSet<NSString *> *)eventNames dataSource:(id<LAEventDataSource>)dataSource {
    for (NSString *eventName in eventNames) {
        [self.activator la_unregisterEventDataSourceWithEventName:eventName ifOwnedByDataSource:dataSource];
    }
}

- (BOOL)synchronizeEventNames:(NSSet<NSString *> *)eventNames
           previousEventNames:(NSSet<NSString *> *)previousEventNames
                  forProvider:(id<LATEventDefinitionProvider>)provider {
    id<LATEventDefinitionRegistryDelegate> delegate = self.delegate;
    if (!delegate || [eventNames isEqualToSet:previousEventNames]) {
        return YES;
    }
    return [delegate eventDefinitionRegistry:self
                             applyEventNames:eventNames
                          previousEventNames:previousEventNames
                                 forProvider:provider];
}

- (void)replaceEventNameIndexForProvider:(id<LATEventDefinitionProvider>)provider
                      previousEventNames:(NSSet<NSString *> *)previousEventNames
                              eventNames:(NSSet<NSString *> *)eventNames {
    for (NSString *eventName in previousEventNames) {
        if (self.providersByEventName[eventName] == provider) {
            [self.providersByEventName removeObjectForKey:eventName];
        }
    }
    for (NSString *eventName in eventNames) {
        self.providersByEventName[eventName] = provider;
    }
}

- (void)publishChange {
    self.generation += 1;
    [NSNotificationCenter.defaultCenter postNotificationName:[self.class changedNotification] object:self];
}

- (BOOL)isPropertyListValue:(id)value {
    if (!value) {
        return NO;
    }
    return [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0];
}

- (nullable id)immutablePropertyListSnapshot:(id)value {
    if (![self isPropertyListValue:value]) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&error];
    if (!data) {
        return nil;
    }
    return [NSPropertyListSerialization propertyListWithData:data
                                                     options:NSPropertyListImmutable
                                                      format:nil
                                                       error:&error];
}

@end
