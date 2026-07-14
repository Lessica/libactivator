//
//  LATestEventDefinitionRegistrySuite.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventDefinitionRegistrySuite.h"

#import "LAActivator+Private.h"
#import "LATEventDefinitionRegistry.h"
#import "LATEventDispatcher.h"
#import "LATEventSourceDefinitionBinding.h"
#import "LATEventSourceRegistry.h"
#import "LATNetworkEventDataSource.h"
#import "LATNetworkEventSource.h"
#import "LATestEnvironment.h"
#import "LATestEventDataSource.h"
#import "LATestEventDefinitionProvider.h"
#import "LATestListener.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@interface LATNetworkEventSource (LATestEventDefinitionRegistry)
- (void)la_testingSendWiFiEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName;
@end

@interface LATestEventDefinitionRegistryDelegate : NSObject <LATEventDefinitionRegistryDelegate>

@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSSet<NSString *> *> *eventNamesByProviderIdentifier;
@property(nonatomic, assign) NSUInteger applyCount;
@property(nonatomic, assign) BOOL failNextApply;
@property(nonatomic, assign) BOOL observedDefinitionBeforeMapping;
@property(nonatomic, assign) BOOL observedMappingBeforeDefinitionRemoval;
@property(nonatomic, copy, nullable) BOOL (^applyHandler)
    (id<LATEventDefinitionProvider> provider, NSSet<NSString *> *eventNames, NSSet<NSString *> *previousEventNames);

- (instancetype)initWithActivator:(LAActivator *)activator;

@end

@implementation LATestEventDefinitionRegistryDelegate

- (instancetype)initWithActivator:(LAActivator *)activator {
    self = [super init];
    if (self) {
        _activator = activator;
        _eventNamesByProviderIdentifier = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)eventDefinitionRegistry:(__unused LATEventDefinitionRegistry *)registry
                applyEventNames:(NSSet<NSString *> *)eventNames
             previousEventNames:(NSSet<NSString *> *)previousEventNames
                    forProvider:(id<LATEventDefinitionProvider>)provider {
    NSMutableSet<NSString *> *addedEventNames = [eventNames mutableCopy];
    [addedEventNames minusSet:previousEventNames];
    NSMutableSet<NSString *> *removedEventNames = [previousEventNames mutableCopy];
    [removedEventNames minusSet:eventNames];

    BOOL additionsAreRegistered = YES;
    for (NSString *eventName in addedEventNames) {
        additionsAreRegistered = additionsAreRegistered &&
                                 [self.activator eventDataSourceForEventName:eventName] == provider.eventDataSource;
    }
    BOOL removalsAreStillRegistered = YES;
    for (NSString *eventName in removedEventNames) {
        removalsAreStillRegistered = removalsAreStillRegistered &&
                                     [self.activator eventDataSourceForEventName:eventName] == provider.eventDataSource;
    }
    if (addedEventNames.count > 0) {
        self.observedDefinitionBeforeMapping = additionsAreRegistered;
    }
    if (removedEventNames.count > 0 && removalsAreStillRegistered) {
        self.observedMappingBeforeDefinitionRemoval = YES;
    }

    self.applyCount += 1;
    if (self.failNextApply) {
        self.failNextApply = NO;
        return NO;
    }
    if (self.applyHandler && !self.applyHandler(provider, eventNames, previousEventNames)) {
        return NO;
    }
    self.eventNamesByProviderIdentifier[provider.eventDefinitionProviderIdentifier] = [eventNames copy];
    return YES;
}

@end

@implementation LATestEventDefinitionRegistrySuite

+ (id)persistedLegacyPreferenceValueForKey:(NSString *)key {
    NSString *path = @"/var/mobile/Library/Caches/libactivator.tests.plist";
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return nil;
    }

    id propertyList = [NSPropertyListSerialization propertyListWithData:data
                                                                options:NSPropertyListImmutable
                                                                 format:nil
                                                                  error:nil];
    NSDictionary *dictionary = [propertyList isKindOfClass:NSDictionary.class] ? propertyList : nil;
    NSDictionary *legacyPreferences =
        [dictionary[@"LegacyPreferences"] isKindOfClass:NSDictionary.class] ? dictionary[@"LegacyPreferences"] : nil;
    return legacyPreferences[key];
}

+ (LATNetworkEventSource *)networkEventSourceWithActivator:(LAActivator *)activator {
    id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying, LATEventDefinitionQuerying>
        eventDispatcher = [[LATEventDispatcher alloc] initWithActivator:activator];
    return [[LATNetworkEventSource alloc] initWithEventDispatcher:eventDispatcher
                                                     modeProvider:eventDispatcher
                                               definitionQuerying:eventDispatcher];
}

+ (LATEventSourceDefinitionBinding *)definitionBindingWithProvider:(id<LATEventDefinitionProvider>)provider
                                                            source:(LATNetworkEventSource *)source {
    return [[LATEventSourceDefinitionBinding alloc] initWithProvider:provider eventSource:source];
}

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"EventDefinitionRegistry"];

    NSString *eventNameA = @"libactivator.test.event-definition-registry.a";
    NSString *eventNameB = @"libactivator.test.event-definition-registry.b";
    NSString *eventNameC = @"libactivator.test.event-definition-registry.c";
    NSString *eventNameD = @"libactivator.test.event-definition-registry.d";
    NSString *eventNameE = @"libactivator.test.event-definition-registry.e";
    NSString *preownedEventName = @"libactivator.test.event-definition-registry.preowned";
    for (NSString *eventName in @[ eventNameA, eventNameB, eventNameC, eventNameD, eventNameE, preownedEventName ]) {
        [activator unregisterEventDataSourceWithEventName:eventName];
    }

    LATEventDefinitionRegistry *registry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
    LATestEventDefinitionRegistryDelegate *delegate =
        [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
    registry.delegate = delegate;
    LATestEventDefinitionProvider *provider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing"
                                                       eventNames:[NSSet setWithObject:eventNameA]];
    [recorder expect:[registry registerProvider:provider] && registry.providers.count == 1 &&
                     [registry providerWithIdentifier:@"testing"] == provider &&
                     [registry providerForEventName:eventNameA] == provider &&
                     [activator eventDataSourceForEventName:eventNameA] == provider
            caseName:@"definition-registry-registers-provider-catalog"
              reason:@"Definition registry did not publish the provider's initial catalog"];

    LATEventDefinitionRegistry *secondRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
    LATestEventDefinitionRegistryDelegate *secondDelegate =
        [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
    secondRegistry.delegate = secondDelegate;
    [recorder expect:![secondRegistry registerProvider:provider]
            caseName:@"definition-registry-rejects-provider-attached-to-another-registry"
              reason:@"One dynamic definition provider was attached to two registries"];
    [secondRegistry invalidate];

    LATEventSourceRegistry *sourceRegistry = [[LATEventSourceRegistry alloc] initWithActivator:activator];
    [recorder expect:[sourceRegistry eventSourcesForEventName:eventNameA].count == 0
            caseName:@"definition-registry-allows-metadata-only-definition"
              reason:@"A dynamic definition was incorrectly treated as an acquisition producer"];

    LATestEventDefinitionProvider *duplicateProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing" eventNames:[NSSet set]];
    [recorder expect:![registry registerProvider:duplicateProvider]
            caseName:@"definition-registry-rejects-duplicate-provider-identifier"
              reason:@"Definition registry accepted two providers with the same identifier"];

    NSDictionary<NSString *, id> *catalog = [registry eventCreationCatalog];
    NSArray *catalogProviders = catalog[@"Providers"];
    BOOL validCatalog = [NSPropertyListSerialization propertyList:catalog
                                                 isValidForFormat:NSPropertyListBinaryFormat_v1_0];
    [recorder expect:validCatalog && [catalog[@"Generation"] unsignedIntegerValue] == registry.generation &&
                     catalogProviders.count == 1 &&
                     [catalogProviders.firstObject[@"Identifier"] isEqualToString:@"testing"] &&
                     [catalogProviders.firstObject[@"Templates"] count] == 1
            caseName:@"definition-registry-exposes-property-list-creation-catalog"
              reason:@"Definition registry did not expose a generation-bound provider catalog"];

    delegate.observedDefinitionBeforeMapping = NO;
    NSUInteger generationBeforeCreate = registry.generation;
    __block BOOL availableEventsObserverSawCommittedDefinition = NO;
    id availableEventsObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:LAActivatorAvailableEventsChangedNotification
                    object:activator
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    if ([activator hasEventWithName:eventNameB]) {
                        NSSet<NSString *> *mappedEventNames =
                            delegate.eventNamesByProviderIdentifier[provider.eventDefinitionProviderIdentifier];
                        availableEventsObserverSawCommittedDefinition =
                            [registry providerForEventName:eventNameB] == provider &&
                            [mappedEventNames containsObject:eventNameB] &&
                            [activator eventDataSourceForEventName:eventNameB] == provider &&
                            [registry.eventCreationCatalog[@"Generation"] unsignedIntegerValue] ==
                                generationBeforeCreate + 1;
                    }
                }];
    NSString *createdEventName = [registry createEventWithProviderIdentifier:@"testing"
                                                          templateIdentifier:@"testing"
                                                               configuration:@{@"EventName" : eventNameB}
                                                          expectedGeneration:generationBeforeCreate];
    [NSNotificationCenter.defaultCenter removeObserver:availableEventsObserver];
    [recorder
          expect:[createdEventName isEqualToString:eventNameB] && registry.generation == generationBeforeCreate + 1 &&
                 [provider.eventDefinitionNames containsObject:eventNameB] &&
                 [registry providerForEventName:eventNameB] == provider &&
                 [activator eventDataSourceForEventName:eventNameB] == provider &&
                 delegate.observedDefinitionBeforeMapping && availableEventsObserverSawCommittedDefinition
        caseName:@"definition-registry-generically-creates-event"
          reason:@"Generic creation exposed a partial provider, definition, acquisition, or generation state"];

    [recorder expect:[registry createEventWithProviderIdentifier:@"testing"
                                              templateIdentifier:@"testing"
                                                   configuration:@{@"EventName" : eventNameE}
                                              expectedGeneration:generationBeforeCreate] == nil &&
                     ![provider.eventDefinitionNames containsObject:eventNameE]
            caseName:@"definition-registry-rejects-stale-create-generation"
              reason:@"Generic creation accepted a stale provider catalog generation"];
    [recorder expect:[registry createEventWithProviderIdentifier:@"testing"
                                              templateIdentifier:@"testing"
                                                   configuration:@{@"Invalid" : NSUUID.UUID}
                                              expectedGeneration:registry.generation] == nil
            caseName:@"definition-registry-rejects-non-property-list-creation"
              reason:@"Generic creation accepted a non-property-list payload"];

    NSUInteger generationBeforeNoOp = registry.generation;
    NSUInteger applyCountBeforeNoOp = delegate.applyCount;
    [recorder expect:[[registry createEventWithProviderIdentifier:@"testing"
                                               templateIdentifier:@"testing"
                                                    configuration:@{@"EventName" : eventNameB}
                                               expectedGeneration:generationBeforeNoOp] isEqualToString:eventNameB] &&
                     registry.generation == generationBeforeNoOp && delegate.applyCount == applyCountBeforeNoOp
            caseName:@"definition-registry-no-op-does-not-publish-change"
              reason:@"An unchanged dynamic definition mutation advanced generation or remapped acquisition"];

    provider.configurationClassName = NSStringFromClass(LAEventConfigurationViewController.class);
    provider.configurationBundle = [NSBundle bundleForClass:LAEventConfigurationViewController.class];
    provider.configuration = @{@"Enabled" : @YES};
    NSUInteger configurationGeneration = registry.generation;
    id configuration = [registry configurationForEventName:eventNameB expectedGeneration:configurationGeneration];
    BOOL savedConfiguration = [registry saveConfiguration:@{@"Enabled" : @NO}
                                             forEventName:eventNameB
                                       expectedGeneration:configurationGeneration];
    [recorder expect:[configuration isEqual:@{@"Enabled" : @YES}] && savedConfiguration &&
                     [provider.lastSavedConfiguration isEqual:@{@"Enabled" : @NO}] &&
                     [registry configurationForEventName:eventNameB
                                      expectedGeneration:configurationGeneration - 1] == nil
            caseName:@"definition-registry-generation-guards-existing-event-configuration"
              reason:@"Definition generation did not guard configuration read and save"];

    delegate.observedDefinitionBeforeMapping = NO;
    delegate.observedMappingBeforeDefinitionRemoval = NO;
    NSUInteger generationBeforeDiff = registry.generation;
    NSUInteger applyCountBeforeDiff = delegate.applyCount;
    BOOL appliedDiff = [provider replaceEventDefinitionNames:[NSSet setWithObjects:eventNameB, eventNameC, nil]];
    [recorder expect:appliedDiff && registry.generation == generationBeforeDiff + 1 &&
                     delegate.applyCount == applyCountBeforeDiff + 1 && ![activator hasEventWithName:eventNameA] &&
                     [activator eventDataSourceForEventName:eventNameB] == provider &&
                     [activator eventDataSourceForEventName:eventNameC] == provider &&
                     delegate.observedDefinitionBeforeMapping && delegate.observedMappingBeforeDefinitionRemoval
            caseName:@"definition-registry-atomically-applies-added-removed-unchanged-diff"
              reason:@"Definition registry did not apply one coherent provider diff"];

    LATestEventDataSource *foreignDataSource = [[LATestEventDataSource alloc] init];
    [activator registerEventDataSource:foreignDataSource forEventName:eventNameD];
    NSUInteger generationBeforeConflict = registry.generation;
    NSUInteger applyCountBeforeConflict = delegate.applyCount;
    BOOL appliedConflict =
        [provider replaceEventDefinitionNames:[NSSet setWithObjects:eventNameB, eventNameC, eventNameD, nil]];
    [recorder expect:!appliedConflict && registry.generation == generationBeforeConflict &&
                     delegate.applyCount == applyCountBeforeConflict &&
                     [provider.eventDefinitionNames isEqualToSet:[NSSet setWithObjects:eventNameB, eventNameC, nil]] &&
                     [activator eventDataSourceForEventName:eventNameD] == foreignDataSource
            caseName:@"definition-registry-preflight-conflict-keeps-previous-snapshot"
              reason:@"A foreign definition conflict partially changed provider or registry state"];

    delegate.failNextApply = YES;
    NSUInteger generationBeforeMappingFailure = registry.generation;
    BOOL appliedMappingFailure =
        [provider replaceEventDefinitionNames:[NSSet setWithObjects:eventNameB, eventNameE, nil]];
    [recorder expect:!appliedMappingFailure && registry.generation == generationBeforeMappingFailure &&
                     [provider.eventDefinitionNames isEqualToSet:[NSSet setWithObjects:eventNameB, eventNameC, nil]] &&
                     [activator eventDataSourceForEventName:eventNameC] == provider &&
                     ![activator hasEventWithName:eventNameE]
            caseName:@"definition-registry-mapping-failure-rolls-back-definition-update"
              reason:@"A failed acquisition mapping left a partial definition update"];

    LATestEventDataSource *delegateReplacementDataSource = [[LATestEventDataSource alloc] init];
    __block BOOL delegateReplacedOwner = NO;
    delegate.applyHandler = ^BOOL(id<LATEventDefinitionProvider> appliedProvider, NSSet<NSString *> *eventNames,
                                  NSSet<NSString *> *previousEventNames) {
        if (appliedProvider == provider && [eventNames containsObject:eventNameE] &&
            ![previousEventNames containsObject:eventNameE] && !delegateReplacedOwner) {
            delegateReplacedOwner = YES;
            [activator registerEventDataSource:delegateReplacementDataSource forEventName:eventNameE];
        }
        return YES;
    };
    NSUInteger generationBeforeDelegateReplacement = registry.generation;
    BOOL appliedDelegateReplacement =
        [provider replaceEventDefinitionNames:[NSSet setWithObjects:eventNameB, eventNameC, eventNameE, nil]];
    delegate.applyHandler = nil;
    NSSet<NSString *> *mappedEventNamesAfterDelegateReplacement =
        delegate.eventNamesByProviderIdentifier[provider.eventDefinitionProviderIdentifier];
    [recorder expect:delegateReplacedOwner && !appliedDelegateReplacement &&
                     registry.generation == generationBeforeDelegateReplacement &&
                     [provider.eventDefinitionNames isEqualToSet:[NSSet setWithObjects:eventNameB, eventNameC, nil]] &&
                     [registry providerForEventName:eventNameE] == nil &&
                     [activator eventDataSourceForEventName:eventNameE] == delegateReplacementDataSource &&
                     ![mappedEventNamesAfterDelegateReplacement containsObject:eventNameE]
            caseName:@"definition-registry-delegate-owner-replacement-rolls-back-mutation"
              reason:@"A delegate-side owner replacement left a committed provider definition or acquisition mapping"];
    if ([provider.eventDefinitionNames containsObject:eventNameE]) {
        [provider replaceEventDefinitionNames:[NSSet setWithObjects:eventNameB, eventNameC, nil]];
    }
    [activator unregisterEventDataSourceWithEventName:eventNameE];

    NSString *reentrantEventName = @"libactivator.test.event-definition-registry.unregister-reentrant";
    [activator unregisterEventDataSourceWithEventName:reentrantEventName];
    LATEventDefinitionRegistry *reentrantRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
    LATestEventDefinitionRegistryDelegate *reentrantDelegate =
        [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
    reentrantRegistry.delegate = reentrantDelegate;
    LATestEventDefinitionProvider *unregisteringProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing.unregistering"
                                                       eventNames:[NSSet setWithObject:reentrantEventName]];
    LATestEventDefinitionProvider *reentrantProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing.unregister-reentrant"
                                                       eventNames:[NSSet set]];
    BOOL registeredUnregisteringProvider = [reentrantRegistry registerProvider:unregisteringProvider];
    __block BOOL acceptedReentrantProvider = NO;
    reentrantDelegate.applyHandler = ^BOOL(id<LATEventDefinitionProvider> appliedProvider,
                                           NSSet<NSString *> *eventNames, NSSet<NSString *> *previousEventNames) {
        if (appliedProvider == unregisteringProvider && eventNames.count == 0 && previousEventNames.count > 0) {
            acceptedReentrantProvider = [reentrantRegistry registerProvider:reentrantProvider];
        }
        return YES;
    };
    BOOL unregisteredWithReentrantDelegate = [reentrantRegistry unregisterProvider:unregisteringProvider];
    reentrantDelegate.applyHandler = nil;
    [recorder
          expect:registeredUnregisteringProvider && unregisteredWithReentrantDelegate && !acceptedReentrantProvider &&
                 [reentrantRegistry providerWithIdentifier:reentrantProvider.eventDefinitionProviderIdentifier] ==
                     nil &&
                 ![activator hasEventWithName:reentrantEventName]
        caseName:@"definition-registry-rejects-unregister-delegate-reentrancy"
          reason:@"Provider unregistration allowed its delegate to mutate the registry reentrantly"];
    if ([reentrantRegistry providerWithIdentifier:reentrantProvider.eventDefinitionProviderIdentifier] ==
        reentrantProvider) {
        [reentrantRegistry unregisterProvider:reentrantProvider];
    }
    [reentrantRegistry invalidate];
    [activator unregisterEventDataSourceWithEventName:reentrantEventName];

    NSString *inactiveEventNameA = @"libactivator.test.event-definition-registry.inactive-a";
    NSString *inactiveEventNameB = @"libactivator.test.event-definition-registry.inactive-b";
    [activator unregisterEventDataSourceWithEventName:inactiveEventNameA];
    [activator unregisterEventDataSourceWithEventName:inactiveEventNameB];
    LATEventDefinitionRegistry *inactiveRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
    LATestEventDefinitionRegistryDelegate *inactiveDelegate =
        [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
    inactiveRegistry.delegate = inactiveDelegate;
    LATestEventDefinitionProvider *inactiveProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing.inactive"
                                                       eventNames:[NSSet setWithObject:inactiveEventNameA]];
    LATestEventDataSource *inactiveForeignDataSource = [[LATestEventDataSource alloc] init];
    BOOL registeredInactiveProvider = [inactiveRegistry registerProvider:inactiveProvider];
    [activator registerEventDataSource:inactiveForeignDataSource forEventName:inactiveEventNameA];
    BOOL addedAlongsideInactiveForeignDefinition = [inactiveProvider
        replaceEventDefinitionNames:[NSSet setWithObjects:inactiveEventNameA, inactiveEventNameB, nil]];
    NSSet<NSString *> *activeInactiveProviderEventNames =
        [inactiveRegistry activeEventNamesForProvider:inactiveProvider];
    NSSet<NSString *> *mappedInactiveProviderEventNames =
        inactiveDelegate.eventNamesByProviderIdentifier[inactiveProvider.eventDefinitionProviderIdentifier];
    [recorder expect:registeredInactiveProvider && addedAlongsideInactiveForeignDefinition &&
                     [inactiveProvider.eventDefinitionNames
                         isEqualToSet:[NSSet setWithObjects:inactiveEventNameA, inactiveEventNameB, nil]] &&
                     [activeInactiveProviderEventNames isEqualToSet:[NSSet setWithObject:inactiveEventNameB]] &&
                     [mappedInactiveProviderEventNames isEqualToSet:[NSSet setWithObject:inactiveEventNameB]] &&
                     [inactiveRegistry providerForEventName:inactiveEventNameA] == nil &&
                     [inactiveRegistry providerForEventName:inactiveEventNameB] == inactiveProvider &&
                     [activator eventDataSourceForEventName:inactiveEventNameA] == inactiveForeignDataSource &&
                     [activator eventDataSourceForEventName:inactiveEventNameB] == inactiveProvider
            caseName:@"definition-registry-inactive-foreign-definition-does-not-block-new-name"
              reason:@"A declared but foreign-owned inactive definition blocked an unrelated new definition"];
    [inactiveRegistry unregisterProvider:inactiveProvider];
    [inactiveRegistry invalidate];
    [activator unregisterEventDataSourceWithEventName:inactiveEventNameA];
    [activator unregisterEventDataSourceWithEventName:inactiveEventNameB];

    LATestEventDefinitionProvider *preownedProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing.preowned"
                                                       eventNames:[NSSet setWithObject:preownedEventName]];
    [activator registerEventDataSource:preownedProvider forEventName:preownedEventName];
    BOOL registeredPreownedProvider = [registry registerProvider:preownedProvider];
    BOOL unregisteredPreownedProvider = [registry unregisterProvider:preownedProvider];
    [recorder expect:registeredPreownedProvider && unregisteredPreownedProvider &&
                     [activator eventDataSourceForEventName:preownedEventName] == preownedProvider
            caseName:@"definition-registry-does-not-adopt-preexisting-ownership"
              reason:@"Definition registry removed a definition owned before provider registration"];

    NSUInteger generationBeforeReplacement = registry.generation;
    [activator registerEventDataSource:foreignDataSource forEventName:eventNameB];
    NSSet<NSString *> *mappedEventNamesAfterReplacement =
        delegate.eventNamesByProviderIdentifier[provider.eventDefinitionProviderIdentifier];
    [recorder expect:[registry providerForEventName:eventNameB] == nil &&
                     [activator eventDataSourceForEventName:eventNameB] == foreignDataSource &&
                     ![mappedEventNamesAfterReplacement containsObject:eventNameB] &&
                     [provider.eventDefinitionNames containsObject:eventNameB] &&
                     registry.generation == generationBeforeReplacement + 1
            caseName:@"definition-registry-observes-owner-replacement"
              reason:@"Definition registry retained active ownership after a foreign replacement"];

    [activator unregisterEventDataSourceWithEventName:eventNameB];
    [recorder expect:[registry providerForEventName:eventNameB] == provider &&
                     [activator eventDataSourceForEventName:eventNameB] == provider
            caseName:@"definition-registry-reclaims-declared-definition-after-replacement-removal"
              reason:@"Definition registry did not restore a still-declared definition after foreign removal"];

    [activator registerEventDataSource:foreignDataSource forEventName:eventNameB];
    BOOL unregisteredProvider = [registry unregisterProvider:provider];
    [recorder expect:unregisteredProvider && [activator eventDataSourceForEventName:eventNameB] == foreignDataSource &&
                     ![activator hasEventWithName:eventNameC] && sourceRegistry.eventSources.count == 0
            caseName:@"definition-registry-teardown-is-owner-safe-and-source-independent"
              reason:@"Provider teardown removed a replacement or mutated the source registry"];

    [activator unregisterEventDataSourceWithEventName:eventNameB];
    [activator unregisterEventDataSourceWithEventName:eventNameD];
    [activator unregisterEventDataSourceWithEventName:preownedEventName];
    [sourceRegistry invalidate];
    [registry invalidate];
    [recorder expect:registry.isInvalidated &&
                     ![registry registerProvider:[[LATestEventDefinitionProvider alloc]
                                                     initWithIdentifier:@"testing.after-invalidate"
                                                             eventNames:[NSSet set]]]
            caseName:@"definition-registry-invalidation-is-terminal"
              reason:@"Definition registry accepted a provider after terminal invalidation"];

    [self runNetworkProviderIntegrationWithRecorder:recorder activator:activator];
}

+ (void)runNetworkProviderIntegrationWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    static NSString *const networkPreferenceKey = @"LANetworkStatusEvents";
    NSString *networkName = [NSString stringWithFormat:@"libactivator-test-%@", NSUUID.UUID.UUIDString.lowercaseString];
    NSString *configuredEventName = [LAEventNameNetworkJoinedWiFi stringByAppendingFormat:@".%@", networkName];
    id previousPreference = [[activator _getObjectForPreference:networkPreferenceKey] copy];
    NSString *previousProfileName = [activator.currentProfileName copy] ?: @"Default";
    NSString *specificListenerName = @"libactivator.test.event-definition-registry.network-specific";
    NSString *baseListenerName = @"libactivator.test.event-definition-registry.network-base";
    LAEvent *baseEvent = [LAEvent eventWithName:LAEventNameNetworkJoinedWiFi mode:LAEventModeSpringBoard];
    [activator setCurrentProfileName:@"Default"];
    NSArray<NSString *> *previousBaseAssignments = [[activator assignedListenerNamesForEvent:baseEvent] copy];
    [activator setCurrentProfileName:previousProfileName];

    __block LATNetworkEventSource *source = [self networkEventSourceWithActivator:activator];
    __block LATEventSourceRegistry *sourceRegistry = nil;
    __block LATNetworkEventDataSource *provider = [[LATNetworkEventDataSource alloc] initWithActivator:activator];
    __block LATEventSourceDefinitionBinding *binding = [self definitionBindingWithProvider:provider source:source];
    LATEventDefinitionRegistry *definitionRegistry = nil;
    LATestEventDefinitionRegistryDelegate *delegate = nil;
    __block BOOL mappingRemovedBeforeDefinition = NO;

    [activator _setObject:@[] forPreference:networkPreferenceKey];
    sourceRegistry = [[LATEventSourceRegistry alloc] initWithActivator:activator];
    definitionRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
    delegate = [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
    delegate.applyHandler = ^BOOL(id<LATEventDefinitionProvider> appliedProvider, NSSet<NSString *> *eventNames,
                                  __unused NSSet<NSString *> *previousEventNames) {
        if (appliedProvider != provider) {
            return NO;
        }
        BOOL removingConfiguredEvent = ![eventNames containsObject:configuredEventName] &&
                                       [source.configuredEventNames containsObject:configuredEventName];
        if (![binding applyEventNames:eventNames
                   previousEventNames:previousEventNames
                  eventSourceRegistry:sourceRegistry]) {
            return NO;
        }
        if (removingConfiguredEvent) {
            mappingRemovedBeforeDefinition = [sourceRegistry eventSourcesForEventName:configuredEventName].count == 0 &&
                                             [activator hasEventWithName:configuredEventName];
        }
        return YES;
    };
    definitionRegistry.delegate = delegate;

    BOOL sourceRegistered = [sourceRegistry registerEventSource:source];
    BOOL providerRegistered = [definitionRegistry registerProvider:provider];
    [recorder expect:sourceRegistered && providerRegistered && source.configuredEventNames.count == 0 &&
                     [sourceRegistry eventSourcesForEventName:LAEventNameNetworkJoinedWiFi].count == 1
            caseName:@"network-provider-composes-definition-and-base-acquisition-separately"
              reason:@"Network provider registration did not preserve the independent base acquisition source"];
    if (sourceRegistered && providerRegistered) {

        NSUInteger generationBeforeCreate = definitionRegistry.generation;
        NSString *addedEventName = [definitionRegistry createEventWithProviderIdentifier:@"network"
                                                                      templateIdentifier:LAEventNameNetworkJoinedWiFi
                                                                           configuration:@{@"NetworkName" : networkName}
                                                                      expectedGeneration:generationBeforeCreate];
        NSArray *persistedEventNames = [activator _getObjectForPreference:networkPreferenceKey];
        [recorder expect:[addedEventName isEqualToString:configuredEventName] &&
                         [provider.configuredEventNames containsObject:configuredEventName] &&
                         [source.configuredEventNames containsObject:configuredEventName] &&
                         [definitionRegistry providerForEventName:configuredEventName] == provider &&
                         [sourceRegistry eventSourcesForEventName:configuredEventName].firstObject == source &&
                         [activator eventDataSourceForEventName:configuredEventName] == provider &&
                         [persistedEventNames containsObject:configuredEventName]
                caseName:@"network-provider-generic-create-publishes-four-state-planes"
                  reason:@"Network creation did not align provider, definition, source mapping, and persistence"];

        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
        NSArray *persistedEventNamesOnDisk = [self persistedLegacyPreferenceValueForKey:networkPreferenceKey];
        [recorder expect:[persistedEventNamesOnDisk containsObject:configuredEventName]
                caseName:@"network-provider-persists-exact-event-to-disk"
                  reason:@"Network provider exact definition did not survive a backend reload"];

        NSString *localizedTitle = [activator localizedTitleForEventName:configuredEventName];
        BOOL exactCompatible = [activator eventWithName:configuredEventName
                                   isCompatibleWithMode:LAEventModeSpringBoard];
        BOOL baseCompatible = [activator eventWithName:LAEventNameNetworkJoinedWiFi
                                  isCompatibleWithMode:LAEventModeSpringBoard];
        [recorder expect:[activator eventWithNameSupportsRemoval:configuredEventName] &&
                         [localizedTitle containsString:networkName] && exactCompatible == baseCompatible
                caseName:@"network-provider-exposes-exact-event-metadata"
                  reason:@"Network provider did not expose removal, localization, or compatibility metadata"];

        [definitionRegistry invalidate];
        [sourceRegistry invalidate];

        source = [self networkEventSourceWithActivator:activator];
        sourceRegistry = [[LATEventSourceRegistry alloc] initWithActivator:activator];
        provider = [[LATNetworkEventDataSource alloc] initWithActivator:activator];
        binding = [self definitionBindingWithProvider:provider source:source];
        definitionRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
        delegate = [[LATestEventDefinitionRegistryDelegate alloc] initWithActivator:activator];
        delegate.applyHandler = ^BOOL(id<LATEventDefinitionProvider> appliedProvider, NSSet<NSString *> *eventNames,
                                      __unused NSSet<NSString *> *previousEventNames) {
            if (appliedProvider != provider) {
                return NO;
            }
            BOOL removingConfiguredEvent = ![eventNames containsObject:configuredEventName] &&
                                           [source.configuredEventNames containsObject:configuredEventName];
            if (![binding applyEventNames:eventNames
                       previousEventNames:previousEventNames
                      eventSourceRegistry:sourceRegistry]) {
                return NO;
            }
            if (removingConfiguredEvent) {
                mappingRemovedBeforeDefinition =
                    [sourceRegistry eventSourcesForEventName:configuredEventName].count == 0 &&
                    [activator hasEventWithName:configuredEventName];
            }
            return YES;
        };
        definitionRegistry.delegate = delegate;
        BOOL restoredSourceRegistered = [sourceRegistry registerEventSource:source];
        BOOL restoredProviderRegistered = [definitionRegistry registerProvider:provider];
        [recorder expect:restoredSourceRegistered && restoredProviderRegistered &&
                         [provider.configuredEventNames containsObject:configuredEventName] &&
                         [source.configuredEventNames containsObject:configuredEventName] &&
                         [definitionRegistry providerForEventName:configuredEventName] == provider &&
                         [sourceRegistry eventSourcesForEventName:configuredEventName].firstObject == source
                caseName:@"network-provider-restores-definition-and-acquisition-mapping"
                  reason:@"A fresh composition did not restore persisted Network definition and producer state"];
        mappingRemovedBeforeDefinition = NO;

        LATestListener *specificListener = [[LATestListener alloc] init];
        LATestListener *baseListener = [[LATestListener alloc] init];
        specificListener.handlesReceivedEvents = YES;
        [activator registerListener:specificListener forName:specificListenerName];
        [activator registerListener:baseListener forName:baseListenerName];
        [activator setCurrentProfileName:@"Default"];
        LAEvent *specificEvent = [LAEvent eventWithName:configuredEventName mode:LAEventModeSpringBoard];
        [activator assignEvent:baseEvent toListenerWithName:baseListenerName];
        [activator assignEvent:specificEvent toListenerWithName:specificListenerName];

        [source la_testingSendWiFiEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
        BOOL handledSpecificSuppressedBase = specificListener.receiveCount == 1 && baseListener.receiveCount == 0;
        specificListener.handlesReceivedEvents = NO;
        [source la_testingSendWiFiEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
        [recorder expect:handledSpecificSuppressedBase && specificListener.receiveCount == 2 &&
                         baseListener.receiveCount == 1
                caseName:@"network-source-specific-event-handled-fallback"
                  reason:@"Network source did not suppress or fall back to the base event according to handled state"];
        [activator setCurrentProfileName:@"Testing"];
        [activator assignEvent:specificEvent toListenerWithName:specificListenerName];
        [activator setCurrentProfileName:@"Default"];
        BOOL removed = [definitionRegistry removeEventWithName:configuredEventName
                                            expectedGeneration:definitionRegistry.generation];
        BOOL defaultProfileAssignmentRemoved = [activator assignedListenerNamesForEvent:specificEvent].count == 0;
        [activator setCurrentProfileName:@"Testing"];
        BOOL testingProfileAssignmentRemoved = [activator assignedListenerNamesForEvent:specificEvent].count == 0;
        NSArray *persistedEventNamesAfterRemoval = [activator _getObjectForPreference:networkPreferenceKey];
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
        NSArray *persistedEventNamesOnDiskAfterRemoval =
            [self persistedLegacyPreferenceValueForKey:networkPreferenceKey];
        [recorder
              expect:removed && mappingRemovedBeforeDefinition && defaultProfileAssignmentRemoved &&
                     testingProfileAssignmentRemoved &&
                     ![provider.configuredEventNames containsObject:configuredEventName] &&
                     ![source.configuredEventNames containsObject:configuredEventName] &&
                     ![activator hasEventWithName:configuredEventName] &&
                     ![persistedEventNamesAfterRemoval containsObject:configuredEventName] &&
                     ![persistedEventNamesOnDiskAfterRemoval containsObject:configuredEventName] &&
                     [sourceRegistry eventSourcesForEventName:configuredEventName].count == 0 &&
                     [sourceRegistry eventSourcesForEventName:LAEventNameNetworkJoinedWiFi].firstObject == source
            caseName:@"network-provider-removes-mapping-before-definition-and-preserves-base-source"
              reason:@"Network removal left definition, assignment, exact mapping, or base acquisition inconsistent"];
    }
    [definitionRegistry invalidate];
    [sourceRegistry invalidate];
    [activator la_unassignEventNameFromAllProfilesAndNotifyIfChanged:configuredEventName];
    [activator setCurrentProfileName:@"Default"];
    [activator assignEvent:baseEvent toListenersWithNames:previousBaseAssignments];
    [activator setCurrentProfileName:previousProfileName];
    [activator unregisterListenerWithName:specificListenerName];
    [activator unregisterListenerWithName:baseListenerName];
    [activator _setObject:previousPreference forPreference:networkPreferenceKey];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    id restoredPreference = [self persistedLegacyPreferenceValueForKey:networkPreferenceKey];
    [recorder expect:(previousPreference == nil && restoredPreference == nil) ||
                     [restoredPreference isEqual:previousPreference]
            caseName:@"network-provider-restores-original-preference"
              reason:@"Network provider test did not restore the original preference on disk"];
}

@end
