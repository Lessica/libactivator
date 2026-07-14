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
#import "LATEventDispatcher.h"
#import "LATEventSourceDefinitionBinding.h"
#import "LATEventSourceRegistry.h"
#import "LATFingerprintSensorEventSource.h"
#import "LATForceTouchEventSource.h"
#import "LATGestureBarEventSource.h"
#import "LATHardwareActionListener.h"
#import "LATLockStateEventSource.h"
#import "LATMediaEventSource.h"
#import "LATMotionEventSource.h"
#import "LATMultiTouchEventSource.h"
#import "LATNetworkEventSource.h"
#import "LATNothingListener.h"
#import "LATPowerStateEventSource.h"
#import "LATRuntimeStateSource.h"
#import "LATSpringBoardIconGestureEventSource.h"
#import "LATStatusBarEventSource.h"
#import "LATSystemActionListener.h"
#import "LATTelephonyActionListener.h"
#import "LATURLActionListener.h"
#import "LATVolumeHUDTapEventSource.h"

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
@property(nonatomic, strong, readwrite) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readwrite) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, strong) LATEventDispatcher *eventDispatcher;
@property(nonatomic, strong)
    NSMapTable<id<LATEventDefinitionProvider>, LATEventSourceDefinitionBinding *> *bindingsByProvider;

@end

@implementation LATBuiltInRegistry

+ (NSArray<Class> *)builtInEventSourceClasses {
    return @[
        LATFingerprintSensorEventSource.class,
        LATLockStateEventSource.class,
        LATPowerStateEventSource.class,
        LATMediaEventSource.class,
        LATMotionEventSource.class,
        LATNetworkEventSource.class,
        LATButtonEventSource.class,
        LATVolumeHUDTapEventSource.class,
        LATGestureBarEventSource.class,
        LATForceTouchEventSource.class,
        LATMultiTouchEventSource.class,
        LATSpringBoardIconGestureEventSource.class,
        LATStatusBarEventSource.class,
        LATEdgeGestureEventSource.class,
    ];
}

+ (NSArray<Class> *)builtInListenerClasses {
    return @[
        LATNothingListener.class,
        LATURLActionListener.class,
        LATHardwareActionListener.class,
        LATSystemActionListener.class,
        LATComposeActionListener.class,
        LATCameraActionListener.class,
        LATTelephonyActionListener.class,
    ];
}

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
        _bindingsByProvider = [[NSMapTable alloc]
            initWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                  valueOptions:NSPointerFunctionsStrongMemory
                      capacity:0];
        if (![self registerBuiltInEventSourcesWithActivator:activator]) {
            HBLogError(@"Unable to register built-in Event Sources");
        }

        [self registerBuiltInListenersWithActivator:activator];
    }
    return self;
}

- (BOOL)registerBuiltInEventSourcesWithActivator:(LAActivator *)activator {
    NSMutableArray<id<LATEventSource>> *registeredEventSources = [[NSMutableArray alloc] init];
    NSMutableArray<id<LATEventDefinitionProvider>> *registeredProviders = [[NSMutableArray alloc] init];

    for (Class<LATEventSource> eventSourceClass in self.class.builtInEventSourceClasses) {
        LATEventSourceContext *context = [[LATEventSourceContext alloc] initWithActivator:activator
                                                                          eventDispatcher:self.eventDispatcher
                                                                  runtimeLockStateUpdater:self.runtimeStateSource
                                                                     previousEventSources:registeredEventSources];
        id<LATEventSource> eventSource = [[(Class)eventSourceClass alloc] initWithEventSourceContext:context];
        if (!eventSource) {
            continue;
        }
        if (![self.eventSourceRegistry registerEventSource:eventSource]) {
            HBLogError(@"Unable to register Event Source class %@", NSStringFromClass(eventSourceClass));
            [eventSource invalidate];
            [self rollbackEventSources:registeredEventSources definitionProviders:registeredProviders];
            return NO;
        }
        [registeredEventSources addObject:eventSource];

        if (![eventSource respondsToSelector:@selector(eventDefinitionProviderForContext:)]) {
            continue;
        }
        id<LATEventDefinitionProvider> provider = [eventSource eventDefinitionProviderForContext:context];
        if (!provider || ![eventSource conformsToProtocol:@protocol(LATEventSourceDefinitionConsumer)]) {
            HBLogError(@"Event Source %@ returned an invalid definition provider", eventSource.eventSourceIdentifier);
            [self rollbackEventSources:registeredEventSources definitionProviders:registeredProviders];
            return NO;
        }

        LATEventSourceDefinitionBinding *binding = [[LATEventSourceDefinitionBinding alloc]
            initWithProvider:provider
                 eventSource:(id<LATEventSourceDefinitionConsumer>)eventSource];
        [self.bindingsByProvider setObject:binding forKey:provider];
        if (!self.eventDefinitionRegistry.delegate) {
            self.eventDefinitionRegistry.delegate = self;
        }
        if (self.eventDefinitionRegistry.delegate != self ||
            ![self.eventDefinitionRegistry registerProvider:provider]) {
            HBLogError(@"Unable to register Event Source definition provider %@",
                       provider.eventDefinitionProviderIdentifier);
            [self rollbackEventSources:registeredEventSources definitionProviders:registeredProviders];
            return NO;
        }
        [registeredProviders addObject:provider];
    }
    return YES;
}

- (void)rollbackEventSources:(NSArray<id<LATEventSource>> *)eventSources
         definitionProviders:(NSArray<id<LATEventDefinitionProvider>> *)definitionProviders {
    BOOL providerRollbackFailed = NO;
    for (id<LATEventDefinitionProvider> provider in definitionProviders.reverseObjectEnumerator) {
        if (![self.eventDefinitionRegistry unregisterProvider:provider]) {
            providerRollbackFailed = YES;
        }
    }
    if (providerRollbackFailed) {
        HBLogError(@"Unable to roll back all Event Source definition providers");
        [self.eventDefinitionRegistry invalidate];
    }
    if (self.eventDefinitionRegistry.providers.count == 0 && self.eventDefinitionRegistry.delegate == self) {
        self.eventDefinitionRegistry.delegate = nil;
    }

    BOOL sourceRollbackFailed = NO;
    for (id<LATEventSource> eventSource in eventSources.reverseObjectEnumerator) {
        if (![self.eventSourceRegistry unregisterEventSource:eventSource]) {
            sourceRollbackFailed = YES;
        }
    }
    if (sourceRollbackFailed) {
        HBLogError(@"Unable to roll back all Event Sources");
        [self.eventSourceRegistry invalidate];
    }
    [self.bindingsByProvider removeAllObjects];
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

- (void)startEventSources {
    [self.runtimeStateSource start];
    [self.eventSourceRegistry start];
}

- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol {
    if (!protocol) {
        return @[];
    }
    NSMutableArray<id> *matchingEventSources = [[NSMutableArray alloc] init];
    for (id<LATEventSource> eventSource in self.eventSourceRegistry.eventSources) {
        if ([eventSource conformsToProtocol:protocol]) {
            [matchingEventSources addObject:eventSource];
        }
    }
    return [matchingEventSources copy];
}

- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason {
    [self.dynamicApplicationListenerProvider noteApplicationsMayHaveChangedWithReason:reason];
}

- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled {
    return [self.activator la_hasRealHomeButton];
}

- (void)registerBuiltInListenersWithActivator:(LAActivator *)activator {
    LATBuiltInListenerContext *context =
        [[LATBuiltInListenerContext alloc] initWithApplicationLauncher:self.applicationLauncher
                                                    runtimeStateSource:self.runtimeStateSource
                                           springBoardInstanceProvider:self
                                                          eventSources:self.eventSourceRegistry.eventSources];

    for (Class<LATBuiltInListenerRegistrant> listenerClass in self.class.builtInListenerClasses) {
        NSMutableArray<NSString *> *listenerNames = [[NSMutableArray alloc] init];
        for (NSString *listenerName in [listenerClass supportedListenerNames]) {
            if ([listenerClass listenerNameHasRequiredMetadata:listenerName activator:activator]) {
                [listenerNames addObject:listenerName];
            } else {
                HBLogWarn(@"Skipping %@ %@ because required metadata is missing or mismatched",
                          NSStringFromClass(listenerClass), listenerName);
            }
        }
        if (listenerNames.count == 0) {
            continue;
        }

        id<LATBuiltInListenerRegistrant> listener =
            [[(Class)listenerClass alloc] initWithBuiltInListenerContext:context];
        if (!listener) {
            HBLogError(@"Unable to create built-in listener class %@", NSStringFromClass(listenerClass));
            continue;
        }
        [self.registeredListeners addObject:listener];
        for (NSString *listenerName in listenerNames) {
            [activator registerListener:listener forName:listenerName];
        }
    }

    LATApplicationActionListener *applicationListener =
        [[LATApplicationActionListener alloc] initWithLauncher:self.applicationLauncher
                                            runtimeStateSource:self.runtimeStateSource
                                   springBoardInstanceProvider:self];
    [self.registeredListeners addObject:applicationListener];

    LATApplicationCatalog *applicationCatalog = [[LATApplicationCatalog alloc] init];
    self.dynamicApplicationListenerProvider =
        [[LATApplicationListenerProvider alloc] initWithActivator:activator
                                                          catalog:applicationCatalog
                                                         listener:applicationListener];
    [self.dynamicApplicationListenerProvider start];
}

@end
