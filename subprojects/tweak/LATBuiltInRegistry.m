//
//  LATBuiltInRegistry.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInRegistry.h"

#import "LAActivator+Private.h"
#import "LARuntimeContext.h"
#import "LATApplicationActionListener.h"
#import "LATApplicationCatalog.h"
#import "LATApplicationLauncher.h"
#import "LATApplicationListenerProvider.h"
#import "LATBuiltInListenerRegistrant.h"
#import "LATButtonEventSource.h"
#import "LATCameraActionListener.h"
#import "LATComposeActionListener.h"
#import "LATEdgeGestureEventSource.h"
#import "LATEventDefinitionRegistry.h"
#import "LATEventSourceRegistry.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATForceTouchEventSource.h"
#import "LATHardwareActionListener.h"
#import "LATLockStateEventSource.h"
#import "LATMediaEventSource.h"
#import "LATMultiTouchEventSource.h"
#import "LATNetworkEventDataSource.h"
#import "LATNetworkEventSource.h"
#import "LATNothingListener.h"
#import "LATPowerStateEventSource.h"
#import "LATRuntimeStateSource.h"
#import "LATSpringBoardIconGestureEventSource.h"
#import "LATStatusBarEventSource.h"
#import "LATSystemActionListener.h"
#import "LATTelephonyActionListener.h"
#import "LATURLActionListener.h"

#import <HBLog.h>

@interface LATBuiltInRegistry () <LATEventDefinitionRegistryDelegate>

// Dependencies
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;

// Listener registration
@property(nonatomic, strong) LATApplicationListenerProvider *dynamicApplicationListenerProvider;
@property(nonatomic, strong) NSMutableArray<id<LAListener>> *registeredListeners;

// Event sources
@property(nonatomic, strong, readwrite) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readwrite) LATButtonEventSource *buttonEventSource;
@property(nonatomic, strong, readwrite) LATEdgeGestureEventSource *edgeGestureEventSource;
@property(nonatomic, strong, readwrite) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readwrite) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, strong, readwrite, nullable) LATFingerprintSensorEventSource *fingerprintSensorEventSource;
@property(nonatomic, strong, readwrite, nullable) LATForceTouchEventSource *forceTouchEventSource;
@property(nonatomic, strong, readwrite) LATLockStateEventSource *lockStateEventSource;
@property(nonatomic, strong, readwrite) LATMediaEventSource *mediaEventSource;
@property(nonatomic, strong, readwrite) LATMultiTouchEventSource *multiTouchEventSource;
@property(nonatomic, strong, readwrite) LATNetworkEventSource *networkEventSource;
@property(nonatomic, strong) LATNetworkEventDataSource *networkEventDataSource;
@property(nonatomic, strong, readwrite) LATPowerStateEventSource *powerStateEventSource;
@property(nonatomic, strong, readwrite) LATSpringBoardIconGestureEventSource *springBoardIconGestureEventSource;
@property(nonatomic, strong, readwrite) LATStatusBarEventSource *statusBarEventSource;

@end

@implementation LATBuiltInRegistry

- (instancetype)initWithActivator:(LAActivator *)activator {
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
        _applicationLauncher = [[LATApplicationLauncher alloc] init];
        _registeredListeners = [[NSMutableArray alloc] init];

        LARuntimeContext *runtimeContext = [activator la_runtimeContext];
        NSParameterAssert(runtimeContext);

        _runtimeStateSource = [[LATRuntimeStateSource alloc] initWithRuntimeContext:runtimeContext];
        _eventSourceRegistry = [[LATEventSourceRegistry alloc] initWithActivator:activator];
        _eventDefinitionRegistry = [[LATEventDefinitionRegistry alloc] initWithActivator:activator];
        _eventDefinitionRegistry.delegate = self;
        _lockStateEventSource = [[LATLockStateEventSource alloc] initWithRuntimeStateSource:_runtimeStateSource];
        _powerStateEventSource = [[LATPowerStateEventSource alloc] init];
        _mediaEventSource = [[LATMediaEventSource alloc] init];
        _networkEventSource = [[LATNetworkEventSource alloc] init];
        _networkEventDataSource = [[LATNetworkEventDataSource alloc] initWithActivator:activator];
        _buttonEventSource = [[LATButtonEventSource alloc] init];
        if ([self fingerprintSensorEventSourceShouldBeRegisteredWithActivator:activator]) {
            _fingerprintSensorEventSource = [[LATFingerprintSensorEventSource alloc] init];
        }
        if ([self forceTouchEventSourceShouldBeRegisteredWithActivator:activator]) {
            _forceTouchEventSource = [[LATForceTouchEventSource alloc] init];
        }
        _lockStateEventSource.fingerprintSensorEventSource = _fingerprintSensorEventSource;
        _statusBarEventSource = [[LATStatusBarEventSource alloc] init];
        _edgeGestureEventSource = [[LATEdgeGestureEventSource alloc] init];
        _edgeGestureEventSource.fingerprintSensorEventSource = _fingerprintSensorEventSource;
        _multiTouchEventSource = [[LATMultiTouchEventSource alloc] init];
        _springBoardIconGestureEventSource = [[LATSpringBoardIconGestureEventSource alloc] init];

        NSMutableArray<id<LATEventSource>> *eventSources =
            [[NSMutableArray alloc] initWithObjects:_lockStateEventSource, _powerStateEventSource, _mediaEventSource,
                                                    _networkEventSource, _buttonEventSource, nil];
        if (_fingerprintSensorEventSource) {
            [eventSources addObject:_fingerprintSensorEventSource];
        }
        if (_forceTouchEventSource) {
            [eventSources addObject:_forceTouchEventSource];
        }
        [eventSources addObjectsFromArray:@[
            _multiTouchEventSource,
            _springBoardIconGestureEventSource,
            _statusBarEventSource,
            _edgeGestureEventSource,
        ]];
        for (id<LATEventSource> eventSource in eventSources) {
            if (![_eventSourceRegistry registerEventSource:eventSource]) {
                HBLogWarn(@"Unable to register built-in event source %@", eventSource.eventSourceIdentifier);
            }
        }
        if (![_eventDefinitionRegistry registerProvider:_networkEventDataSource]) {
            HBLogWarn(@"Unable to register built-in Network event definition provider");
        }

        [self registerBuiltInListenersWithActivator:activator];
    }
    return self;
}

- (BOOL)eventDefinitionRegistry:(__unused LATEventDefinitionRegistry *)registry
                applyEventNames:(NSSet<NSString *> *)eventNames
             previousEventNames:(__unused NSSet<NSString *> *)previousEventNames
                    forProvider:(id<LATEventDefinitionProvider>)provider {
    if (provider != self.networkEventDataSource) {
        HBLogWarn(@"No acquisition mapping is configured for dynamic definition provider %@",
                  provider.eventDefinitionProviderIdentifier);
        return NO;
    }

    NSSet<NSString *> *previousConfiguredEventNames = self.networkEventSource.configuredEventNames;
    [self.networkEventSource updateConfiguredEventNames:eventNames];
    if ([self.eventSourceRegistry reloadEventNamesForEventSource:self.networkEventSource]) {
        return YES;
    }

    [self.networkEventSource updateConfiguredEventNames:previousConfiguredEventNames];
    [self.eventSourceRegistry reloadEventNamesForEventSource:self.networkEventSource];
    return NO;
}

- (void)startEventSources {
    [self.runtimeStateSource start];
    [self.eventSourceRegistry start];
}

- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason {
    [self.dynamicApplicationListenerProvider noteApplicationsMayHaveChangedWithReason:reason];
}

- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled {
    return [self.activator la_hasRealHomeButton];
}

- (BOOL)fingerprintSensorEventSourceShouldBeRegisteredWithActivator:(LAActivator *)activator {
    return [[activator availableEventNames] containsObject:LAEventNameFingerprintSensorPressSingle];
}

- (BOOL)forceTouchEventSourceShouldBeRegisteredWithActivator:(LAActivator *)activator {
    return [[activator availableEventNames] containsObject:LAEventNameForceTouchScreenBottom];
}

- (NSArray<NSDictionary<NSString *, id> *> *)builtInListenerFactoryConfigurations {
    return @[
        @{
            @"RegistrantClass" : LATURLActionListener.class,
            @"MissingMetadataReason" : @"URL metadata is missing",
        },
        @{
            @"RegistrantClass" : LATHardwareActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
        @{
            @"RegistrantClass" : LATSystemActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
        @{
            @"RegistrantClass" : LATComposeActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
        @{
            @"RegistrantClass" : LATCameraActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
        @{
            @"RegistrantClass" : LATTelephonyActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
    ];
}

- (id<LAListener>)createListenerForRegistrantClass:(Class<LATBuiltInListenerRegistrant>)registrantClass {
    if (registrantClass == LATSystemActionListener.class) {
        return [[LATSystemActionListener alloc] initWithLauncher:self.applicationLauncher registry:self];
    }
    if (registrantClass == LATHardwareActionListener.class) {
        return [[LATHardwareActionListener alloc] initWithMediaEventSource:self.mediaEventSource];
    }
    if (registrantClass == LATCameraActionListener.class) {
        return [[LATCameraActionListener alloc] initWithLauncher:self.applicationLauncher registry:self];
    }
    return [[(Class)registrantClass alloc] init];
}

- (void)registerListener:(id<LAListener>)listener
          registrantClass:(Class<LATBuiltInListenerRegistrant>)registrantClass
                activator:(LAActivator *)activator
    missingMetadataReason:(NSString *)missingMetadataReason {
    for (NSString *listenerName in [registrantClass supportedListenerNames]) {
        if ([registrantClass listenerNameHasRequiredMetadata:listenerName activator:activator]) {
            [activator registerListener:listener forName:listenerName];
        } else {
            HBLogWarn(@"Skipping %@ %@ because %@", NSStringFromClass(registrantClass), listenerName,
                      missingMetadataReason);
        }
    }
}

- (void)registerBuiltInListenersWithActivator:(LAActivator *)activator {
    LATNothingListener *nothingListener = [[LATNothingListener alloc] init];
    [self.registeredListeners addObject:nothingListener];
    [activator registerListener:nothingListener forName:@"libactivator.system.nothing"];

    for (NSDictionary<NSString *, id> *configuration in [self builtInListenerFactoryConfigurations]) {
        Class<LATBuiltInListenerRegistrant> registrantClass = configuration[@"RegistrantClass"];
        NSString *missingMetadataReason = configuration[@"MissingMetadataReason"];
        if (!registrantClass || missingMetadataReason.length == 0) {
            continue;
        }

        id<LAListener> listener = [self createListenerForRegistrantClass:registrantClass];
        if (!listener) {
            continue;
        }

        [self.registeredListeners addObject:listener];
        [self registerListener:listener
                  registrantClass:registrantClass
                        activator:activator
            missingMetadataReason:missingMetadataReason];
    }

    LATApplicationActionListener *applicationListener =
        [[LATApplicationActionListener alloc] initWithLauncher:self.applicationLauncher registry:self];
    [self.registeredListeners addObject:applicationListener];

    LATApplicationCatalog *applicationCatalog = [[LATApplicationCatalog alloc] init];
    self.dynamicApplicationListenerProvider =
        [[LATApplicationListenerProvider alloc] initWithActivator:activator
                                                          catalog:applicationCatalog
                                                         listener:applicationListener];
    [self.dynamicApplicationListenerProvider start];
}

@end
