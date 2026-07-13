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
#import "LATCameraActionListener.h"
#import "LATComposeActionListener.h"
#import "LATEventDefinitionRegistry.h"
#import "LATEventDispatcher.h"
#import "LATEventSourceModule.h"
#import "LATEventSourceModuleLoader.h"
#import "LATEventSourceRegistry.h"
#import "LATHardwareActionListener.h"
#import "LATNothingListener.h"
#import "LATRuntimeStateSource.h"
#import "LATSystemActionListener.h"
#import "LATTelephonyActionListener.h"
#import "LATURLActionListener.h"

#import <HBLog.h>

@interface LATBuiltInRegistry ()

// Dependencies
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;

// Listener registration
@property(nonatomic, strong) LATApplicationListenerProvider *dynamicApplicationListenerProvider;
@property(nonatomic, strong) NSMutableArray<id<LAListener>> *registeredListeners;

// Event sources
@property(nonatomic, strong, readwrite) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readwrite) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readwrite) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, strong) LATEventDispatcher *eventDispatcher;
@property(nonatomic, strong) LATEventSourceModuleContext *eventSourceModuleContext;
@property(nonatomic, strong) LATEventSourceModuleLoader *eventSourceModuleLoader;

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
        _eventDispatcher = [[LATEventDispatcher alloc] initWithActivator:activator];
        _eventSourceModuleContext = [[LATEventSourceModuleContext alloc] initWithActivator:activator
                                                                           eventDispatcher:_eventDispatcher
                                                                   runtimeLockStateUpdater:_runtimeStateSource];
        _eventSourceModuleLoader = [[LATEventSourceModuleLoader alloc] initWithContext:_eventSourceModuleContext
                                                                   eventSourceRegistry:_eventSourceRegistry
                                                               eventDefinitionRegistry:_eventDefinitionRegistry];
        if (![_eventSourceModuleLoader loadModules]) {
            HBLogError(@"Unable to load built-in Event Source modules");
        }

        [self registerBuiltInListenersWithActivator:activator];
    }
    return self;
}

- (void)startEventSources {
    [self.runtimeStateSource start];
    [self.eventSourceRegistry start];
}

- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol {
    return [self.eventSourceModuleLoader eventSourcesConformingToProtocol:protocol];
}

- (id)eventSourceServiceForProtocol:(Protocol *)protocol {
    return [self.eventSourceModuleLoader serviceForProtocol:protocol];
}

- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason {
    [self.dynamicApplicationListenerProvider noteApplicationsMayHaveChangedWithReason:reason];
}

- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled {
    return [self.activator la_hasRealHomeButton];
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
        id<LATNowPlayingProviding> nowPlayingProvider =
            [self eventSourceServiceForProtocol:@protocol(LATNowPlayingProviding)];
        return [[LATHardwareActionListener alloc] initWithNowPlayingProvider:nowPlayingProvider];
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
