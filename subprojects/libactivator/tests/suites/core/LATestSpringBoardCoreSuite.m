//
//  LATestSpringBoardCoreSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestSpringBoardCoreSuite.h"

#import "LATestEnvironment.h"

@implementation LATestSpringBoardCoreSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"SpringBoardCore"];

    NSString *eventName = @"libactivator.test.core";
    NSString *listenerAName = @"libactivator.test.listener.a";
    NSString *listenerBName = @"libactivator.test.listener.b";
    NSString *listenerCName = @"libactivator.test.listener.c";
    NSString *unseenListenerName = @"libactivator.test.listener.unseen";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *listenerA = [[LATestListener alloc] init];
    LATestListener *listenerB = [[LATestListener alloc] init];
    LATestListener *listenerC = [[LATestListener alloc] init];
    LATestListener *unseenListener = [[LATestListener alloc] init];
    listenerA.exclusiveGroups = @[ @"exclusive" ];
    listenerB.exclusiveGroups = @[ @"exclusive" ];
    listenerC.compatibleModes = @[ LAEventModeSpringBoard ];

    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:listenerA forName:listenerAName];
    [activator registerListener:listenerB forName:listenerBName];
    [activator registerListener:listenerC forName:listenerCName];
    [activator registerListener:unseenListener forName:unseenListenerName ignoreHasSeen:YES];

    [recorder expect:[activator hasEventWithName:eventName]
            caseName:@"event-registry"
              reason:@"Event was not registered"];
    [recorder expect:[activator hasEventWithName:LAEventNameVolumeMuteOn] &&
                     [activator hasEventWithName:LAEventNameVolumeDownPress] &&
                     [activator hasEventWithName:LAEventNameStatusBarTapSingle] &&
                     [activator hasEventWithName:LAEventScreenBottomSwipeLeft] &&
                     [activator hasEventWithName:LAEventScreenRightSwipeUp]
            caseName:@"bundled-event-registry"
              reason:@"1.9.13 bundled event metadata was not registered"];
    [recorder expect:[activator eventWithNameSupportsUnlockingDeviceToSend:LAEventNameFingerprintSensorHold] == NO
            caseName:@"bundled-event-unlock-metadata"
              reason:@"1.9.13 unlock-to-send metadata was not read from bundled events"];
    [recorder expect:[activator assignmentWarningForEventWithName:LAEventNameVolumeMuteOn] == nil
            caseName:@"bundled-event-assignment-warning-fallback"
              reason:@"Missing assignment warning metadata should return nil"];
    id<LAEventDataSource> statusBarDataSource = [activator eventDataSourceForEventName:LAEventNameStatusBarTapSingle];
    BOOL statusBarIsUnprotected = statusBarDataSource &&
                                  [statusBarDataSource respondsToSelector:@selector(eventWithNameIsUnprotected:)] &&
                                  [statusBarDataSource eventWithNameIsUnprotected:LAEventNameStatusBarTapSingle];
    [recorder expect:statusBarIsUnprotected
            caseName:@"bundled-event-unprotected-metadata"
              reason:@"1.9.13 unprotected event metadata was not exposed through the data source"];
    [recorder expect:[activator listenerWithNameNeedsPoweredDisplay:@"libactivator.audio.launch-playing-app"]
            caseName:@"bundled-listener-powered-display-metadata"
              reason:@"1.9.13 listener needs-powered-display metadata was not used as fallback"];
    [recorder expect:[[activator exclusiveAssignmentGroupsForListenerName:@"libactivator.audio.decrease-volume"]
                         isEqualToArray:@[ @"volume-change" ]]
            caseName:@"bundled-listener-exclusive-group-metadata"
              reason:@"1.9.13 listener exclusive assignment group metadata was not used as fallback"];
    NSString *removableEventName = @"libactivator.test.removable-event";
    NSString *nonremovableEventName = @"libactivator.test.nonremovable-event";
    LATestEventDataSource *removableDataSource = [[LATestEventDataSource alloc] init];
    LATestEventDataSource *nonremovableDataSource = [[LATestEventDataSource alloc] init];
    removableDataSource.supportsRemoval = YES;
    [activator registerEventDataSource:removableDataSource forEventName:removableEventName];
    [activator registerEventDataSource:nonremovableDataSource forEventName:nonremovableEventName];
    [activator removeEventWithName:nonremovableEventName];
    [recorder expect:nonremovableDataSource.removalCount == 0 &&
                     [activator eventDataSourceForEventName:nonremovableEventName] == nonremovableDataSource
            caseName:@"event-removal-requires-support"
              reason:@"Event removal ignored supports-removal metadata"];
    [activator removeEventWithName:removableEventName];
    [recorder expect:removableDataSource.removalCount == 1 && ![activator hasEventWithName:removableEventName]
            caseName:@"event-removal-supported"
              reason:@"Supported event removal did not remove the event data source"];

    LATestEventDataSource *reentrantRemovalDataSource = [[LATestEventDataSource alloc] init];
    LATestEventDataSource *reentrantReplacementDataSource = [[LATestEventDataSource alloc] init];
    reentrantRemovalDataSource.supportsRemoval = YES;
    reentrantRemovalDataSource.removalHandler = ^{
        [activator registerEventDataSource:reentrantReplacementDataSource forEventName:removableEventName];
    };
    [activator registerEventDataSource:reentrantRemovalDataSource forEventName:removableEventName];
    [activator removeEventWithName:removableEventName];
    [recorder expect:reentrantRemovalDataSource.removalCount == 1 &&
                     [activator eventDataSourceForEventName:removableEventName] == reentrantReplacementDataSource
            caseName:@"event-removal-preserves-reentrant-replacement"
              reason:@"Event removal deleted a replacement registered by the removal callback"];
    [activator unregisterEventDataSourceWithEventName:removableEventName];
    [activator unregisterEventDataSourceWithEventName:nonremovableEventName];
    __block NSUInteger eventNotificationCount = 0;
    id eventObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableEventsChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        eventNotificationCount += 1;
                                                    }];
    LATestEventDataSource *replacementDataSource = [[LATestEventDataSource alloc] init];
    [activator registerEventDataSource:replacementDataSource forEventName:eventName];
    [recorder expect:[activator eventDataSourceForEventName:eventName] == replacementDataSource &&
                     eventNotificationCount == 0
            caseName:@"event-data-source-overwrite-no-availability-notification"
              reason:@"Event data source overwrite changed availability notification state"];
    [activator registerEventDataSource:[[LATestEventDataSource alloc] init]
                          forEventName:@"libactivator.test.new-event-data-source"];
    [recorder expect:eventNotificationCount == 1
            caseName:@"new-event-data-source-availability-notification"
              reason:@"New event data source registration did not post availability notification"];
    [NSNotificationCenter.defaultCenter removeObserver:eventObserver];

    NSString *ownerSafeEventName = @"libactivator.test.owner-safe-event";
    LATestEventDataSource *ownerDataSource = [[LATestEventDataSource alloc] init];
    LATestEventDataSource *contenderDataSource = [[LATestEventDataSource alloc] init];
    __block NSUInteger ownerEventNotificationCount = 0;
    id ownerEventObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableEventsChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        ownerEventNotificationCount += 1;
                                                    }];
    BOOL ownerRegistered = [activator la_registerEventDataSourceIfAbsent:ownerDataSource
                                                            forEventName:ownerSafeEventName];
    BOOL contenderRegistered = [activator la_registerEventDataSourceIfAbsent:contenderDataSource
                                                                forEventName:ownerSafeEventName];
    [recorder expect:ownerRegistered && !contenderRegistered &&
                     [activator eventDataSourceForEventName:ownerSafeEventName] == ownerDataSource &&
                     ownerEventNotificationCount == 1
            caseName:@"event-data-source-register-if-absent"
              reason:@"Owner-safe event registration did not preserve ownership and notification semantics"];
    [activator registerEventDataSource:contenderDataSource forEventName:ownerSafeEventName];
    BOOL staleOwnerRemoved = [activator la_unregisterEventDataSourceWithEventName:ownerSafeEventName
                                                              ifOwnedByDataSource:ownerDataSource];
    [recorder expect:!staleOwnerRemoved &&
                     [activator eventDataSourceForEventName:ownerSafeEventName] == contenderDataSource &&
                     ownerEventNotificationCount == 1
            caseName:@"event-data-source-owner-safe-unregister-rejects-stale-owner"
              reason:@"Owner-safe event removal changed state or notified for a stale owner"];
    BOOL currentOwnerRemoved = [activator la_unregisterEventDataSourceWithEventName:ownerSafeEventName
                                                                ifOwnedByDataSource:contenderDataSource];
    [recorder expect:currentOwnerRemoved && ![activator hasEventWithName:ownerSafeEventName] &&
                     ownerEventNotificationCount == 2
            caseName:@"event-data-source-owner-safe-unregister"
              reason:@"Owner-safe event removal did not remove and notify for the current owner"];
    [NSNotificationCenter.defaultCenter removeObserver:ownerEventObserver];

    [recorder expect:![activator eventWithNameSupportsConfiguration:eventName] &&
                     [activator configurationViewControllerForEventWithName:eventName] == nil
            caseName:@"event-configuration-unsupported-without-descriptor"
              reason:@"Event configuration was exposed without a class and bundle descriptor"];

    NSString *configurationEventName = @"libactivator.test.configuration-event";
    LATestEventDataSource *configurationDataSource = [[LATestEventDataSource alloc] init];
    configurationDataSource.configurationClassName = NSStringFromClass(LAEventConfigurationViewController.class);
    [activator registerEventDataSource:configurationDataSource forEventName:configurationEventName];
    [recorder expect:![activator eventWithNameSupportsConfiguration:configurationEventName]
            caseName:@"event-configuration-requires-bundle"
              reason:@"Event configuration was exposed without a configuration bundle"];

    configurationDataSource.configurationBundle = [NSBundle bundleForClass:LAEventConfigurationViewController.class];
    NSDictionary<NSString *, NSString *> *configurationDescriptor =
        [activator la_eventConfigurationDescriptorForEventName:configurationEventName];
    [recorder expect:[activator eventWithNameSupportsConfiguration:configurationEventName] &&
                     [configurationDescriptor[LAIPCKeyEventConfigurationClassName]
                         isEqualToString:configurationDataSource.configurationClassName] &&
                     [configurationDescriptor[LAIPCKeyEventConfigurationBundlePath]
                         isEqualToString:configurationDataSource.configurationBundle.bundlePath]
            caseName:@"event-configuration-descriptor"
              reason:@"Event configuration descriptor did not preserve its class name and bundle path"];

    LAEventConfigurationViewController *configurationController =
        [activator configurationViewControllerForEventWithName:configurationEventName];
    [recorder expect:[configurationController isKindOfClass:LAEventConfigurationViewController.class] &&
                     [configurationController.eventName isEqualToString:configurationEventName]
            caseName:@"event-configuration-controller-factory"
              reason:@"Event configuration factory did not create the requested controller locally"];

    NSDictionary *initialConfiguration = @{
        @"Enabled" : @YES,
        @"Threshold" : @2,
    };
    configurationDataSource.configuration = initialConfiguration;
    [recorder
          expect:[[activator la_configurationForEventWithName:configurationEventName] isEqual:initialConfiguration] &&
                 configurationDataSource.configurationRequestCount == 1
        caseName:@"event-configuration-get-bridge"
          reason:@"Event configuration bridge did not request the data source configuration"];

    NSDictionary *savedConfiguration = @{
        @"Enabled" : @NO,
        @"Threshold" : @4,
    };
    BOOL configurationSaved = [activator la_saveConfiguration:savedConfiguration
                                             forEventWithName:configurationEventName];
    [recorder expect:configurationSaved && configurationDataSource.configurationSaveCount == 1 &&
                     [configurationDataSource.lastSavedConfiguration isEqual:savedConfiguration]
            caseName:@"event-configuration-save-bridge"
              reason:@"Event configuration bridge did not save a property-list configuration"];
    BOOL invalidConfigurationSaved = [activator la_saveConfiguration:[[NSObject alloc] init]
                                                    forEventWithName:configurationEventName];
    [recorder expect:!invalidConfigurationSaved && configurationDataSource.configurationSaveCount == 1
            caseName:@"event-configuration-save-rejects-non-property-list"
              reason:@"Event configuration bridge accepted a non-property-list configuration"];

    NSDictionary *nestedInvalidConfiguration = @{
        @"Enabled" : @YES,
        @"Nested" : @{
            @"Invalid" : [[NSObject alloc] init],
        },
    };
    BOOL nestedInvalidConfigurationSaved = [activator la_saveConfiguration:nestedInvalidConfiguration
                                                          forEventWithName:configurationEventName];
    [recorder expect:!nestedInvalidConfigurationSaved && configurationDataSource.configurationSaveCount == 1 &&
                     [configurationDataSource.lastSavedConfiguration isEqual:savedConfiguration] &&
                     [configurationDataSource.configuration isEqual:savedConfiguration]
            caseName:@"event-configuration-save-atomically-rejects-nested-non-property-list"
              reason:@"Event configuration bridge partially accepted a nested non-property-list configuration"];

    configurationDataSource.configuration = nestedInvalidConfiguration;
    [recorder expect:[activator la_configurationForEventWithName:configurationEventName] == nil &&
                     configurationDataSource.configurationRequestCount == 2
            caseName:@"event-configuration-get-atomically-rejects-nested-non-property-list"
              reason:@"Event configuration bridge returned a partially sanitized provider snapshot"];
    configurationDataSource.configuration = savedConfiguration;

    LATestEventDataSource *configurationReplacementDataSource = [[LATestEventDataSource alloc] init];
    configurationReplacementDataSource.configurationClassName =
        NSStringFromClass(LAEventConfigurationViewController.class);
    configurationReplacementDataSource.configurationBundle =
        [NSBundle bundleForClass:LAEventConfigurationViewController.class];
    configurationReplacementDataSource.configuration = @{@"Source" : @"replacement"};
    configurationDataSource.configuration = @{@"Source" : @"snapshot"};
    configurationDataSource.configurationDescriptorRequestHandler = ^{
        [activator registerEventDataSource:configurationReplacementDataSource forEventName:configurationEventName];
    };
    id snapshotConfiguration = [activator la_configurationForEventWithName:configurationEventName];
    configurationDataSource.configurationDescriptorRequestHandler = nil;
    [recorder expect:snapshotConfiguration == nil && configurationDataSource.configurationRequestCount == 2 &&
                     configurationReplacementDataSource.configurationRequestCount == 0
            caseName:@"event-configuration-get-rejects-stale-owner"
              reason:@"Event configuration get read from a data source that lost ownership during descriptor lookup"];

    [activator registerEventDataSource:configurationDataSource forEventName:configurationEventName];
    configurationDataSource.configurationDescriptorRequestHandler = ^{
        [activator registerEventDataSource:configurationReplacementDataSource forEventName:configurationEventName];
    };
    NSDictionary *snapshotSavedConfiguration = @{@"Source" : @"saved-snapshot"};
    BOOL snapshotConfigurationSaved = [activator la_saveConfiguration:snapshotSavedConfiguration
                                                     forEventWithName:configurationEventName];
    configurationDataSource.configurationDescriptorRequestHandler = nil;
    [recorder expect:!snapshotConfigurationSaved && configurationDataSource.configurationSaveCount == 1 &&
                     [configurationDataSource.lastSavedConfiguration isEqual:savedConfiguration] &&
                     configurationReplacementDataSource.configurationSaveCount == 0
            caseName:@"event-configuration-save-rejects-stale-owner"
              reason:@"Event configuration save wrote to a data source that lost ownership during descriptor lookup"];

    [activator registerEventDataSource:configurationDataSource forEventName:configurationEventName];
    configurationDataSource.configurationClassName = NSStringFromClass(LAEventConfigurationViewController.class);
    configurationDataSource.configurationBundle = [NSBundle bundleForClass:NSObject.class];
    [recorder expect:[activator eventWithNameSupportsConfiguration:configurationEventName] &&
                     [activator configurationViewControllerForEventWithName:configurationEventName] == nil
            caseName:@"event-configuration-controller-requires-bundle-provenance"
              reason:@"Event configuration factory accepted a controller from outside the descriptor bundle"];

    configurationDataSource.configurationClassName = NSStringFromClass(NSObject.class);
    configurationDataSource.configurationBundle = [NSBundle bundleForClass:NSObject.class];
    [recorder expect:[activator eventWithNameSupportsConfiguration:configurationEventName] &&
                     [activator configurationViewControllerForEventWithName:configurationEventName] == nil
            caseName:@"event-configuration-controller-requires-base-class"
              reason:@"Event configuration factory created a controller with an invalid base class"];
    [activator unregisterEventDataSourceWithEventName:configurationEventName];

    [recorder expect:[activator hasListenerWithName:listenerAName]
            caseName:@"listener-registry"
              reason:@"Listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:listenerAName]
            caseName:@"seen-listener"
              reason:@"Seen listener was not recorded"];
    [recorder expect:[activator hasListenerWithName:unseenListenerName] &&
                     ![activator hasSeenListenerWithName:unseenListenerName]
            caseName:@"unseen-listener-registration"
              reason:@"ignoreHasSeen listener registration was not preserved"];
    NSString *localizationListenerName = @"libactivator.test.listener.localization";
    LATestListener *localizationListener = [[LATestListener alloc] init];
    localizationListener.localizedTitle = @"Cached Title";
    localizationListener.localizedGroup = @"Cached Group";
    localizationListener.localizedDescription = @"Cached Description";
    [activator registerListener:localizationListener forName:localizationListenerName];
    NSString *firstLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    NSString *firstLocalizedGroup = [activator localizedGroupForListenerName:localizationListenerName];
    NSString *firstLocalizedDescription = [activator localizedDescriptionForListenerName:localizationListenerName];
    localizationListener.localizedTitle = @"Changed Title";
    localizationListener.localizedGroup = @"Changed Group";
    localizationListener.localizedDescription = @"Changed Description";
    NSString *secondLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    NSString *secondLocalizedGroup = [activator localizedGroupForListenerName:localizationListenerName];
    NSString *secondLocalizedDescription = [activator localizedDescriptionForListenerName:localizationListenerName];
    [recorder expect:[firstLocalizedTitle isEqualToString:@"Cached Title"] &&
                     [secondLocalizedTitle isEqualToString:firstLocalizedTitle] &&
                     [firstLocalizedGroup isEqualToString:@"Cached Group"] &&
                     [secondLocalizedGroup isEqualToString:firstLocalizedGroup] &&
                     [firstLocalizedDescription isEqualToString:@"Cached Description"] &&
                     [secondLocalizedDescription isEqualToString:firstLocalizedDescription] &&
                     localizationListener.localizedTitleRequestCount == 1 &&
                     localizationListener.localizedGroupRequestCount == 1 &&
                     localizationListener.localizedDescriptionRequestCount == 1
            caseName:@"listener-localization-cache"
              reason:@"Listener localization lookup did not use the metadata cache"];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
                                                      object:UIApplication.sharedApplication];
    NSString *thirdLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    [recorder expect:[thirdLocalizedTitle isEqualToString:@"Changed Title"] &&
                     localizationListener.localizedTitleRequestCount == 2
            caseName:@"listener-cache-cleared-by-memory-warning"
              reason:@"Listener metadata cache was not cleared by memory warning"];
    LATestListener *replacementLocalizationListener = [[LATestListener alloc] init];
    replacementLocalizationListener.localizedTitle = @"Replacement Title";
    [activator registerListener:replacementLocalizationListener forName:localizationListenerName];
    [recorder expect:[[activator localizedTitleForListenerName:localizationListenerName]
                         isEqualToString:@"Replacement Title"] &&
                     replacementLocalizationListener.localizedTitleRequestCount == 1
            caseName:@"listener-localization-cache-invalidated-by-registration"
              reason:@"Listener localization cache was not invalidated by listener registration"];
    NSString *iconListenerName = @"libactivator.test.listener.icon";
    LATestListener *iconListener = [[LATestListener alloc] init];
    iconListener.smallIconImage = [[UIImage alloc] init];
    [activator registerListener:iconListener forName:iconListenerName];
    UIImage *firstSmallIcon = [activator smallIconForListenerName:iconListenerName];
    iconListener.smallIconImage = nil;
    UIImage *secondSmallIcon = [activator smallIconForListenerName:iconListenerName];
    [recorder expect:firstSmallIcon && firstSmallIcon == secondSmallIcon && iconListener.smallIconRequestCount == 1
            caseName:@"small-icon-cache"
              reason:@"Small listener icon lookup did not use the cache"];
    LATestListener *replacementIconListener = [[LATestListener alloc] init];
    replacementIconListener.smallIconImage = [[UIImage alloc] init];
    [activator registerListener:replacementIconListener forName:iconListenerName];
    UIImage *replacementSmallIcon = [activator smallIconForListenerName:iconListenerName];
    [recorder expect:replacementSmallIcon == replacementIconListener.smallIconImage &&
                     replacementIconListener.smallIconRequestCount == 1
            caseName:@"small-icon-cache-invalidated-by-registration"
              reason:@"Small listener icon cache was not invalidated by listener registration"];
    [recorder expect:[activator smallIconForListenerName:@"com.apple.Preferences"] == nil
            caseName:@"small-icon-no-global-application-fallback"
              reason:@"Core small icon lookup used a global application icon fallback"];
    [activator requestRemovalForListenerWithName:listenerAName];
    [recorder expect:listenerA.removalRequestCount == 0
            caseName:@"listener-removal-request-requires-support"
              reason:@"Listener removal request ignored supports-removal metadata"];
    listenerA.supportsRemoval = YES;
    [activator requestRemovalForListenerWithName:listenerAName];
    [recorder expect:listenerA.removalRequestCount == 1
            caseName:@"listener-removal-request-supported"
              reason:@"Supported listener removal request was not delivered"];
    __block NSUInteger listenerNotificationCount = 0;
    id listenerObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableListenersChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        listenerNotificationCount += 1;
                                                    }];
    LATestListener *replacementListener = [[LATestListener alloc] init];
    replacementListener.exclusiveGroups = @[ @"exclusive" ];
    [activator registerListener:replacementListener forName:listenerAName];
    [recorder expect:[activator listenerForName:listenerAName] == replacementListener && listenerNotificationCount == 0
            caseName:@"listener-overwrite-no-availability-notification"
              reason:@"Listener overwrite changed availability notification state"];
    [activator registerListener:replacementListener forName:@"libactivator.test.listener.new"];
    [recorder expect:listenerNotificationCount == 1
            caseName:@"new-listener-availability-notification"
              reason:@"New listener registration did not post availability notification"];
    [NSNotificationCenter.defaultCenter removeObserver:listenerObserver];
    [recorder expect:![activator listenerNamesAreMutuallyCompatible:@[ listenerAName, listenerBName ]]
            caseName:@"exclusive-groups"
              reason:@"Exclusive listeners were reported compatible"];

    LAEvent *springboardEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:springboardEvent toListenersWithNames:@[ listenerBName, listenerAName ]];
    NSArray *assignedNames = [activator assignedListenerNamesForEvent:springboardEvent];
    [recorder expect:[assignedNames isEqualToArray:@[ listenerAName, listenerBName ]]
            caseName:@"assignment-normalization"
              reason:@"Assignment names were not normalized"];
    [recorder expect:[activator eventsAssignedToListenerWithName:listenerAName].count == 1
            caseName:@"reverse-assignment"
              reason:@"Reverse assignment lookup failed"];

    LAEvent *applicationEvent = [LAEvent eventWithName:eventName mode:LAEventModeApplication];
    [activator assignEvent:applicationEvent toListenerWithName:listenerCName];
    [recorder expect:[activator assignedListenerNamesForEvent:applicationEvent].count == 0
            caseName:@"assignment-compatibility-filter"
              reason:@"Incompatible assignment was returned as active"];
    [recorder
          expect:[activator eventsAssignedToListenerWithName:listenerCName].count == 1
        caseName:@"reverse-assignment-keeps-incompatible"
          reason:@"Reverse assignment should include available events assigned to currently incompatible listeners"];
    [activator addListenerAssignment:listenerAName toEvent:applicationEvent];
    [activator removeListenerAssignment:listenerAName fromEvent:applicationEvent];
    [recorder expect:[activator assignedListenerNamesForEvent:applicationEvent].count == 0 &&
                     [activator eventsAssignedToListenerWithName:listenerCName].count == 1
            caseName:@"incremental-assignment-keeps-incompatible"
              reason:@"Incremental assignment rewrite dropped an incompatible stored assignment"];
    [activator unregisterEventDataSourceWithEventName:eventName];
    [recorder expect:[activator eventsAssignedToListenerWithName:listenerCName].count == 0
            caseName:@"reverse-assignment-hides-unavailable-event"
              reason:@"Reverse assignment exposed an unavailable event"];
    [activator registerEventDataSource:dataSource forEventName:eventName];

    [activator setCurrentProfileName:@"Testing"];
    [recorder expect:[[activator availableProfileNames] containsObject:@"Testing"]
            caseName:@"profile-create"
              reason:@"Profile was not created"];
    [recorder expect:[activator assignedListenerNamesForEvent:springboardEvent].count == 0
            caseName:@"profile-isolation"
              reason:@"Assignments leaked across profiles"];
    [activator setCurrentProfileName:@"Default"];

    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
    [recorder expect:[activator applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"blacklist-set"
              reason:@"Blacklist set failed"];
    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [recorder expect:![activator applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"blacklist-clear"
              reason:@"Blacklist clear failed"];
}

@end
