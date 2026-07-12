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
#import "LATestEnvironment.h"
#import "LATestEventDataSource.h"
#import "LATestEventSource.h"
#import "LATestListener.h"

#import <Activator/Activator.h>

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

    NSString *legacyAssignmentKey =
        [NSString stringWithFormat:@"LAEventListener(%@)-%@", LAEventModeSpringBoard, sharedEventName];
    [activator _setObject:listenerName forPreference:legacyAssignmentKey];
    [recorder expect:[registry isInterestedInEventSource:assignedSource] && assignedSource.isInterested
            caseName:@"registry-interest-follows-legacy-assignment-write"
              reason:@"Legacy assignment preference write did not update Event Source interest immediately"];
    [activator _setObject:nil forPreference:legacyAssignmentKey];
    [recorder expect:![registry isInterestedInEventSource:assignedSource] && !assignedSource.isInterested
            caseName:@"registry-interest-follows-legacy-assignment-removal"
              reason:@"Legacy assignment preference removal did not update Event Source interest immediately"];

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
            caseName:@"registry-reloads-producer-catalog"
              reason:@"Registry did not transactionally replace a source producer catalog"];

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

@end
