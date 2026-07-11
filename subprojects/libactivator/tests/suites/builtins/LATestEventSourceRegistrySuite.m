//
//  LATestEventSourceRegistrySuite.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSourceRegistrySuite.h"

#import "LAActivator+Private.h"
#import "LARuntimeContext.h"
#import "LATEventSourceRegistry.h"
#import "LATNetworkEventDataSource.h"
#import "LATNetworkEventSource.h"
#import "LATestEnvironment.h"
#import "LATestEventDataSource.h"
#import "LATestEventSource.h"
#import "LATestListener.h"

#import <Activator/Activator.h>

@interface LATNetworkEventSource (LATestEventSourceRegistry)
- (void)la_testingSendWiFiEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName;
@end

@implementation LATestEventSourceRegistrySuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"EventSourceRegistry"];

    Class registryClass = NSClassFromString(@"LATEventSourceRegistry");
    [recorder expect:registryClass != Nil
            caseName:@"registry-class-available"
              reason:@"LATEventSourceRegistry was not loaded in SpringBoard"];
    if (!registryClass) {
        return;
    }

    NSString *sharedEventName = @"libactivator.test.event-source-registry.shared";
    NSString *secondaryEventName = @"libactivator.test.event-source-registry.secondary";
    NSString *listenerName = @"libactivator.test.event-source-registry.listener";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *listener = [[LATestListener alloc] init];
    [activator registerEventDataSource:dataSource forEventName:sharedEventName];
    [activator registerEventDataSource:dataSource forEventName:secondaryEventName];
    [activator registerListener:listener forName:listenerName];
    for (NSString *mode in activator.availableEventModes) {
        [activator unassignEvent:[LAEvent eventWithName:sharedEventName mode:mode]];
        [activator unassignEvent:[LAEvent eventWithName:secondaryEventName mode:mode]];
    }

    LARuntimeContext *runtimeContext = [LATestEnvironment runtimeContextForActivator:activator];
    [runtimeContext updateEventMode:LAEventModeSpringBoard
               underneathLockScreen:LAEventModeSpringBoard
                  displayIdentifier:nil
                           screenOn:YES];

    LATEventSourceRegistry *registry = [[registryClass alloc] initWithActivator:activator];
    LATestEventSource *alwaysSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.always"
                                           eventNames:[NSSet setWithObjects:sharedEventName, secondaryEventName, nil]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    LATestEventSource *assignedSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.assigned"
                                           eventNames:[NSSet setWithObjects:sharedEventName, secondaryEventName, nil]
                                       interestPolicy:LATEventSourceInterestPolicyAssignedInCurrentMode];

    [recorder expect:[registry registerEventSource:alwaysSource] && [registry registerEventSource:assignedSource]
            caseName:@"registry-registers-distinct-sources"
              reason:@"Registry rejected valid Event Source registrations"];
    NSArray<id<LATEventSource>> *sharedSources = [registry eventSourcesForEventName:sharedEventName];
    [recorder expect:sharedSources.count == 2 && sharedSources[0] == alwaysSource && sharedSources[1] == assignedSource
            caseName:@"registry-allows-ordered-multiple-producers"
              reason:@"Registry did not retain ordered multiple producers for one event"];
    [recorder expect:registry.eventSources.count == 2 && registry.eventSources[0] == alwaysSource &&
                     registry.eventSources[1] == assignedSource
            caseName:@"registry-preserves-registration-order"
              reason:@"Registry did not preserve deterministic source order"];

    LATestEventSource *duplicateIdentifierSource =
        [[LATestEventSource alloc] initWithIdentifier:alwaysSource.eventSourceIdentifier
                                           eventNames:[NSSet setWithObject:sharedEventName]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    [recorder expect:![registry registerEventSource:duplicateIdentifierSource]
            caseName:@"registry-rejects-duplicate-identifier"
              reason:@"Registry accepted two source objects with the same identifier"];
    [recorder expect:![registry isInterestedInEventSource:alwaysSource] &&
                     ![registry isInterestedInEventSource:assignedSource]
            caseName:@"registry-pre-start-interest-disabled"
              reason:@"Registry exposed source interest before startup"];

    [registry start];
    [recorder expect:alwaysSource.startCount == 1 && assignedSource.startCount == 1
            caseName:@"registry-starts-each-source-once"
              reason:@"Registry did not start each registered source exactly once"];
    [recorder expect:[registry isInterestedInEventSource:alwaysSource] && alwaysSource.isInterested &&
                     ![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-applies-interest-policy"
              reason:@"Registry did not distinguish always-on and assignment-aware sources"];
    [registry start];
    [recorder expect:alwaysSource.startCount == 1 && assignedSource.startCount == 1
            caseName:@"registry-start-is-idempotent"
              reason:@"Repeated registry startup restarted Event Sources"];

    [activator assignEvent:[LAEvent eventWithName:sharedEventName mode:LAEventModeSpringBoard]
        toListenerWithName:listenerName];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested &&
                     [[registry interestedEventNamesForEventSource:assignedSource] containsObject:sharedEventName]
            caseName:@"registry-interest-follows-current-mode-assignment"
              reason:@"Assignment-aware source did not gain interest after assignment"];

    NSUInteger interestedEventNamesChangeCount = assignedSource.interestedEventNamesChangeCount;
    [activator assignEvent:[LAEvent eventWithName:secondaryEventName mode:LAEventModeSpringBoard]
        toListenerWithName:listenerName];
    [recorder expect:assignedSource.isInterested && assignedSource.interestedEventNames.count == 2 &&
                     assignedSource.interestedEventNamesChangeCount == interestedEventNamesChangeCount + 1
            caseName:@"registry-notifies-true-to-true-interest-set-change"
              reason:@"Registry hid a per-event interest change while source-level interest remained true"];
    [activator unassignEvent:[LAEvent eventWithName:secondaryEventName mode:LAEventModeSpringBoard]];

    [runtimeContext updateEventMode:LAEventModeApplication
               underneathLockScreen:LAEventModeApplication
                  displayIdentifier:@"com.apple.Preferences"
                           screenOn:YES];
    [recorder expect:![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-interest-follows-mode-change"
              reason:@"Assignment-aware source retained interest in an unassigned mode"];
    [runtimeContext updateEventMode:LAEventModeSpringBoard
               underneathLockScreen:LAEventModeSpringBoard
                  displayIdentifier:nil
                           screenOn:YES];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested
            caseName:@"registry-interest-restores-with-mode"
              reason:@"Assignment-aware source did not restore interest with its assigned mode"];

    [activator assignEvent:[LAEvent eventWithName:sharedEventName mode:LAEventModeApplication]
        toListenerWithName:listenerName];
    interestedEventNamesChangeCount = assignedSource.interestedEventNamesChangeCount;
    [runtimeContext updateEventMode:LAEventModeApplication
               underneathLockScreen:LAEventModeApplication
                  displayIdentifier:@"com.apple.Preferences"
                           screenOn:YES];
    [recorder expect:assignedSource.isInterested &&
                     assignedSource.interestedEventNamesChangeCount == interestedEventNamesChangeCount + 1
            caseName:@"registry-notifies-mode-change-with-same-interest-set"
              reason:@"Registry did not reset an assignment-aware source when only its event mode changed"];
    [runtimeContext updateEventMode:LAEventModeSpringBoard
               underneathLockScreen:LAEventModeSpringBoard
                  displayIdentifier:nil
                           screenOn:YES];
    [activator unassignEvent:[LAEvent eventWithName:sharedEventName mode:LAEventModeApplication]];

    [activator setCurrentProfileName:@"Testing"];
    [recorder expect:![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-interest-follows-profile-change"
              reason:@"Assignment-aware source retained interest after switching to an unassigned profile"];
    [activator setCurrentProfileName:@"Default"];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested
            caseName:@"registry-interest-restores-with-profile"
              reason:@"Assignment-aware source did not restore interest after returning to the assigned profile"];

    LATestListener *incompatibleReplacementListener = [[LATestListener alloc] init];
    incompatibleReplacementListener.compatibleModes = @[ LAEventModeApplication ];
    [activator registerListener:incompatibleReplacementListener forName:listenerName];
    [recorder expect:![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-interest-follows-listener-replacement"
              reason:@"Assignment-aware source retained interest after its listener became incompatible"];
    [activator registerListener:listener forName:listenerName];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested
            caseName:@"registry-interest-restores-after-listener-replacement"
              reason:@"Assignment-aware source did not restore interest after its compatible listener returned"];

    [activator unregisterEventDataSourceWithEventName:sharedEventName];
    [recorder expect:![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-interest-requires-available-definition"
              reason:@"Assignment-aware source retained interest after its event definition was removed"];
    [activator registerEventDataSource:dataSource forEventName:sharedEventName];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested
            caseName:@"registry-interest-restores-with-definition"
              reason:@"Assignment-aware source did not restore interest after its event definition returned"];

    [recorder expect:[registry unregisterEventSource:assignedSource] && assignedSource.invalidateCount == 1 &&
                     [registry eventSourcesForEventName:sharedEventName].count == 1
            caseName:@"registry-unregister-invalidates-and-unmaps"
              reason:@"Registry did not invalidate and remove a source atomically"];
    [recorder expect:![registry registerEventSource:assignedSource] && assignedSource.startCount == 1
            caseName:@"registry-rejects-invalidated-source-reuse"
              reason:@"Registry accepted a terminally invalidated Event Source object"];

    LATestEventSource *dynamicSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.dynamic"
                                           eventNames:[NSSet setWithObject:secondaryEventName]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    [recorder expect:[registry registerEventSource:dynamicSource] && dynamicSource.startCount == 1
            caseName:@"registry-starts-dynamic-registration"
              reason:@"Registry did not start a source registered after startup"];
    dynamicSource.eventNames = [NSSet setWithObject:sharedEventName];
    [recorder expect:[registry reloadEventNamesForEventSource:dynamicSource] &&
                     ![[registry eventSourcesForEventName:secondaryEventName] containsObject:dynamicSource] &&
                     [[registry eventSourcesForEventName:sharedEventName] containsObject:dynamicSource]
            caseName:@"registry-reloads-dynamic-event-catalog"
              reason:@"Registry did not transactionally replace a source event catalog"];

    NSString *dynamicEventNameA = @"libactivator.test.event-source-registry.dynamic-a";
    NSString *dynamicEventNameB = @"libactivator.test.event-source-registry.dynamic-b";
    NSString *foreignEventName = @"libactivator.test.event-source-registry.foreign";
    NSString *preownedEventName = @"libactivator.test.event-source-registry.preowned";
    NSString *networkName = [NSString stringWithFormat:@"libactivator-test-%@", NSUUID.UUID.UUIDString.lowercaseString];
    NSString *configuredNetworkEventName = [LAEventNameNetworkJoinedWiFi stringByAppendingFormat:@".%@", networkName];
    LATestEventDataSource *dynamicDefinitionDataSource = [[LATestEventDataSource alloc] init];
    LATestEventDataSource *foreignDataSource = [[LATestEventDataSource alloc] init];
    LATestEventSource *dynamicDefinitionSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.dynamic-definition-a"
                                           eventNames:[NSSet setWithObject:dynamicEventNameA]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    [recorder expect:[registry registerEventSource:dynamicDefinitionSource
                              definitionDataSource:dynamicDefinitionDataSource] &&
                     [activator eventDataSourceForEventName:dynamicEventNameA] == dynamicDefinitionDataSource &&
                     dynamicDefinitionSource.startCount == 1
            caseName:@"registry-registers-dynamic-definition-before-source"
              reason:@"Registry did not publish an owned dynamic definition with its acquisition source"];

    dynamicDefinitionSource.eventNames = [NSSet setWithObjects:dynamicEventNameA, dynamicEventNameB, nil];
    [recorder expect:[registry reloadEventNamesForEventSource:dynamicDefinitionSource] &&
                     [activator eventDataSourceForEventName:dynamicEventNameB] == dynamicDefinitionDataSource
            caseName:@"registry-reloads-dynamic-definitions"
              reason:@"Registry did not add a dynamic definition during catalog reload"];

    LATestEventSource *sharedDynamicDefinitionSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.dynamic-definition-b"
                                           eventNames:[NSSet setWithObject:dynamicEventNameB]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    [recorder expect:[registry registerEventSource:sharedDynamicDefinitionSource
                              definitionDataSource:dynamicDefinitionDataSource] &&
                     [registry eventSourcesForEventName:dynamicEventNameB].count == 2
            caseName:@"registry-shares-owned-definition-across-producers"
              reason:@"Registry did not retain one owned definition for multiple acquisition sources"];

    dynamicDefinitionSource.eventNames = [NSSet setWithObject:dynamicEventNameA];
    [registry reloadEventNamesForEventSource:dynamicDefinitionSource];
    [recorder expect:[activator eventDataSourceForEventName:dynamicEventNameB] == dynamicDefinitionDataSource
            caseName:@"registry-keeps-referenced-dynamic-definition"
              reason:@"Registry removed a dynamic definition still used by another producer"];
    [registry unregisterEventSource:dynamicDefinitionSource];
    [recorder expect:![activator hasEventWithName:dynamicEventNameA] &&
                     [activator eventDataSourceForEventName:dynamicEventNameB] == dynamicDefinitionDataSource
            caseName:@"registry-removes-only-unreferenced-dynamic-definition"
              reason:@"Registry did not remove only the definitions released by an acquisition source"];

    [activator registerEventDataSource:foreignDataSource forEventName:foreignEventName];
    LATestEventSource *conflictingDynamicSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.dynamic-definition-conflict"
                                           eventNames:[NSSet setWithObject:foreignEventName]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    [recorder expect:![registry registerEventSource:conflictingDynamicSource
                               definitionDataSource:dynamicDefinitionDataSource] &&
                     [activator eventDataSourceForEventName:foreignEventName] == foreignDataSource &&
                     conflictingDynamicSource.startCount == 0
            caseName:@"registry-rejects-foreign-definition-overwrite"
              reason:@"Registry replaced a bundled or foreign dynamic definition"];

    [activator registerEventDataSource:dynamicDefinitionDataSource forEventName:preownedEventName];
    LATestEventSource *preownedDefinitionSource =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.dynamic-definition-preowned"
                                           eventNames:[NSSet setWithObject:preownedEventName]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    BOOL preownedDefinitionSourceRegistered = [registry registerEventSource:preownedDefinitionSource
                                                       definitionDataSource:dynamicDefinitionDataSource];
    BOOL preownedDefinitionSourceUnregistered = [registry unregisterEventSource:preownedDefinitionSource];
    [recorder expect:preownedDefinitionSourceRegistered && preownedDefinitionSourceUnregistered &&
                     [activator eventDataSourceForEventName:preownedEventName] == dynamicDefinitionDataSource
            caseName:@"registry-does-not-adopt-preexisting-definition-ownership"
              reason:@"Registry teardown removed a definition that the same data source owned beforehand"];
    [activator unregisterEventDataSourceWithEventName:preownedEventName];

    Class networkEventSourceClass = NSClassFromString(@"LATNetworkEventSource");
    if (networkEventSourceClass) {
        LATEventSourceRegistry *networkRegistry = [[registryClass alloc] initWithActivator:activator];
        LATNetworkEventSource *networkSource = [[networkEventSourceClass alloc] init];
        [networkSource updateConfiguredEventNames:[NSSet setWithObject:configuredNetworkEventName]];
        id<LAEventDataSource> baseNetworkDataSource =
            [activator eventDataSourceForEventName:LAEventNameNetworkJoinedWiFi];
        BOOL networkSourceRegistered = [networkRegistry registerEventSource:networkSource
                                                       definitionDataSource:dynamicDefinitionDataSource];
        BOOL networkSourceUnregistered = [networkRegistry unregisterEventSource:networkSource];
        [recorder
              expect:networkSourceRegistered && networkSourceUnregistered && baseNetworkDataSource &&
                     baseNetworkDataSource != dynamicDefinitionDataSource &&
                     [activator eventDataSourceForEventName:LAEventNameNetworkJoinedWiFi] == baseNetworkDataSource &&
                     ![activator hasEventWithName:configuredNetworkEventName]
            caseName:@"registry-owns-only-declared-dynamic-definitions"
              reason:@"Registry conflated a source's bundled producer names with its dynamic definitions"];
    } else {
        [recorder skip:@"registry-owns-only-declared-dynamic-definitions"
                reason:@"LATNetworkEventSource was not loaded"];
    }

    [self runNetworkDynamicProviderTestsWithRecorder:recorder
                                           activator:activator
                                       registryClass:registryClass
                                 configuredEventName:configuredNetworkEventName
                                         networkName:networkName];

    [activator registerEventDataSource:foreignDataSource forEventName:dynamicEventNameB];
    [registry unregisterEventSource:sharedDynamicDefinitionSource];
    [recorder expect:[activator eventDataSourceForEventName:dynamicEventNameB] == foreignDataSource
            caseName:@"registry-owner-safe-definition-unregister"
              reason:@"Registry teardown removed a replacement definition owned by another data source"];
    [activator unregisterEventDataSourceWithEventName:dynamicEventNameB];
    [activator unregisterEventDataSourceWithEventName:foreignEventName];

    [registry invalidate];
    [recorder expect:alwaysSource.invalidateCount == 1 && dynamicSource.invalidateCount == 1 &&
                     registry.eventSources.count == 0
            caseName:@"registry-invalidate-tears-down-sources"
              reason:@"Registry teardown did not invalidate and release all sources"];
    [recorder expect:![registry registerEventSource:duplicateIdentifierSource]
            caseName:@"registry-invalidate-is-terminal"
              reason:@"Registry accepted a source after terminal invalidation"];

    for (NSString *mode in activator.availableEventModes) {
        [activator unassignEvent:[LAEvent eventWithName:sharedEventName mode:mode]];
        [activator unassignEvent:[LAEvent eventWithName:secondaryEventName mode:mode]];
    }
    [activator unregisterListenerWithName:listenerName];
    [activator unregisterEventDataSourceWithEventName:sharedEventName];
    [activator unregisterEventDataSourceWithEventName:secondaryEventName];
    [LATestEnvironment cleanRuntimeInputStateWithActivator:activator];
}

+ (void)runNetworkDynamicProviderTestsWithRecorder:(LATestRecorder *)recorder
                                         activator:(LAActivator *)activator
                                     registryClass:(Class)registryClass
                               configuredEventName:(NSString *)configuredEventName
                                       networkName:(NSString *)networkName {
    Class sourceClass = NSClassFromString(@"LATNetworkEventSource");
    Class providerClass = NSClassFromString(@"LATNetworkEventDataSource");
    if (!sourceClass || !providerClass) {
        [recorder skip:@"network-dynamic-provider" reason:@"Network Event Source provider classes were not loaded"];
        return;
    }

    static NSString *const networkPreferenceKey = @"LANetworkStatusEvents";
    id previousPreference = [activator _getObjectForPreference:networkPreferenceKey];
    [activator _setObject:@[] forPreference:networkPreferenceKey];

    LATNetworkEventSource *source = [[sourceClass alloc] init];
    LATNetworkEventDataSource *provider = [[providerClass alloc] initWithActivator:activator eventSource:source];
    LATEventSourceRegistry *registry = [[registryClass alloc] initWithActivator:activator];
    BOOL registered = [registry registerEventSource:source definitionDataSource:provider];
    [provider attachEventSourceRegistry:registry];
    [recorder expect:registered && source.configuredEventNames.count == 0
            caseName:@"network-provider-registers-base-source"
              reason:@"Network provider did not register an initially empty dynamic definition set"];
    if (!registered) {
        [registry invalidate];
        [activator _setObject:previousPreference forPreference:networkPreferenceKey];
        [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
        return;
    }

    __block NSUInteger availabilityNotificationCount = 0;
    id availabilityObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableEventsChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        availabilityNotificationCount += 1;
                                                    }];
    NSString *addedEventName = [provider addEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
    NSArray *persistedEventNames = [activator _getObjectForPreference:networkPreferenceKey];
    [recorder expect:[addedEventName isEqualToString:configuredEventName] &&
                     [provider.configuredEventNames containsObject:configuredEventName] &&
                     [source.eventNames containsObject:configuredEventName] &&
                     [source.definitionEventNames containsObject:configuredEventName] &&
                     [activator eventDataSourceForEventName:configuredEventName] == provider &&
                     [persistedEventNames containsObject:configuredEventName] && availabilityNotificationCount == 1
            caseName:@"network-provider-adds-and-persists-exact-event"
              reason:@"Network provider did not publish one owner-safe exact SSID definition"];

    NSUInteger notificationCountAfterAdd = availabilityNotificationCount;
    NSString *unchangedEventName = [provider addEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
    [recorder expect:[unchangedEventName isEqualToString:configuredEventName] &&
                     availabilityNotificationCount == notificationCountAfterAdd
            caseName:@"network-provider-unchanged-add-is-idempotent"
              reason:@"Network provider republished an unchanged exact SSID definition"];
    [NSNotificationCenter.defaultCenter removeObserver:availabilityObserver];

    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    LAServerBackend *reloadedBackend = [[LAServerBackend alloc] initWithPersistence:[LAPersistence testingPersistence]];
    NSArray *persistedEventNamesOnDisk = [reloadedBackend objectForLegacyPreferenceKey:networkPreferenceKey];
    [recorder expect:[persistedEventNamesOnDisk containsObject:configuredEventName]
            caseName:@"network-provider-persists-exact-event-to-disk"
              reason:@"Network provider exact SSID definition did not survive a backend reload"];

    NSString *localizedTitle = [activator localizedTitleForEventName:configuredEventName];
    BOOL exactCompatible = [activator eventWithName:configuredEventName isCompatibleWithMode:LAEventModeSpringBoard];
    BOOL baseCompatible = [activator eventWithName:LAEventNameNetworkJoinedWiFi
                              isCompatibleWithMode:LAEventModeSpringBoard];
    [recorder expect:[activator eventWithNameSupportsRemoval:configuredEventName] &&
                     [localizedTitle containsString:networkName] && exactCompatible == baseCompatible
            caseName:@"network-provider-exposes-exact-event-metadata"
              reason:@"Network provider did not expose removal, localization, or compatibility metadata"];

    LATNetworkEventSource *restoredSource = [[sourceClass alloc] init];
    LATNetworkEventDataSource *restoredProvider = [[providerClass alloc] initWithActivator:activator
                                                                               eventSource:restoredSource];
    [recorder expect:[restoredProvider.configuredEventNames containsObject:configuredEventName] &&
                     [restoredSource.eventNames containsObject:configuredEventName]
            caseName:@"network-provider-restores-persisted-exact-event"
              reason:@"Network provider did not restore its authoritative preference snapshot"];

    NSString *specificListenerName = @"libactivator.test.event-source-registry.network-specific";
    NSString *baseListenerName = @"libactivator.test.event-source-registry.network-base";
    LATestListener *specificListener = [[LATestListener alloc] init];
    LATestListener *baseListener = [[LATestListener alloc] init];
    specificListener.handlesReceivedEvents = YES;
    [activator registerListener:specificListener forName:specificListenerName];
    [activator registerListener:baseListener forName:baseListenerName];
    NSString *previousProfileName = activator.currentProfileName;
    [activator setCurrentProfileName:@"Default"];
    LAEvent *baseEvent = [LAEvent eventWithName:LAEventNameNetworkJoinedWiFi mode:LAEventModeSpringBoard];
    LAEvent *specificEvent = [LAEvent eventWithName:configuredEventName mode:LAEventModeSpringBoard];
    NSArray<NSString *> *previousBaseAssignments = [activator assignedListenerNamesForEvent:baseEvent];
    [activator assignEvent:baseEvent toListenerWithName:baseListenerName];
    [activator assignEvent:specificEvent toListenerWithName:specificListenerName];

    [source la_testingSendWiFiEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
    BOOL handledSpecificSuppressedBase = specificListener.receiveCount == 1 && baseListener.receiveCount == 0;
    specificListener.handlesReceivedEvents = NO;
    [source la_testingSendWiFiEventWithBaseName:LAEventNameNetworkJoinedWiFi networkName:networkName];
    [recorder
          expect:handledSpecificSuppressedBase && specificListener.receiveCount == 2 && baseListener.receiveCount == 1
        caseName:@"network-source-specific-event-handled-fallback"
          reason:@"Network source did not suppress or fall back to the base event according to handled state"];
    [activator assignEvent:baseEvent toListenersWithNames:previousBaseAssignments];

    [activator setCurrentProfileName:@"Testing"];
    [activator assignEvent:specificEvent toListenerWithName:specificListenerName];
    [activator setCurrentProfileName:@"Default"];
    [activator removeEventWithName:configuredEventName];
    NSArray *persistedEventNamesAfterRemoval = [activator _getObjectForPreference:networkPreferenceKey];
    BOOL defaultProfileAssignmentRemoved = [activator assignedListenerNamesForEvent:specificEvent].count == 0;
    [activator setCurrentProfileName:@"Testing"];
    BOOL testingProfileAssignmentRemoved = [activator assignedListenerNamesForEvent:specificEvent].count == 0;
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    LAServerBackend *reloadedBackendAfterRemoval =
        [[LAServerBackend alloc] initWithPersistence:[LAPersistence testingPersistence]];
    NSArray *persistedEventNamesOnDiskAfterRemoval =
        [reloadedBackendAfterRemoval objectForLegacyPreferenceKey:networkPreferenceKey];
    [recorder expect:defaultProfileAssignmentRemoved && testingProfileAssignmentRemoved &&
                     ![provider.configuredEventNames containsObject:configuredEventName] &&
                     ![source.eventNames containsObject:configuredEventName] &&
                     ![activator hasEventWithName:configuredEventName] &&
                     ![persistedEventNamesAfterRemoval containsObject:configuredEventName] &&
                     ![persistedEventNamesOnDiskAfterRemoval containsObject:configuredEventName]
            caseName:@"network-provider-removes-definition-and-all-profile-assignments"
              reason:@"Network provider removal left configuration, definition, or profile assignments behind"];

    [activator setCurrentProfileName:previousProfileName];
    [activator unregisterListenerWithName:specificListenerName];
    [activator unregisterListenerWithName:baseListenerName];
    [registry invalidate];
    [activator _setObject:previousPreference forPreference:networkPreferenceKey];
    [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
    LAServerBackend *reloadedBackendAfterRestore =
        [[LAServerBackend alloc] initWithPersistence:[LAPersistence testingPersistence]];
    id restoredPreference = [reloadedBackendAfterRestore objectForLegacyPreferenceKey:networkPreferenceKey];
    [recorder expect:(previousPreference == nil && restoredPreference == nil) ||
                     [restoredPreference isEqual:previousPreference]
            caseName:@"network-provider-restores-original-preference"
              reason:@"Network provider test did not restore the original preference on disk"];
}

@end
