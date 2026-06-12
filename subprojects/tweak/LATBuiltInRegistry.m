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
#import "LATHardwareActionListener.h"
#import "LATLockStateEventSource.h"
#import "LATMediaEventSource.h"
#import "LATNothingListener.h"
#import "LATPowerStateEventSource.h"
#import "LATRuntimeStateSource.h"
#import "LATSystemActionListener.h"
#import "LATTelephonyActionListener.h"
#import "LATURLActionListener.h"

#import <HBLog.h>

@interface LATBuiltInRegistry ()

@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;

@property(nonatomic, strong) LATApplicationListenerProvider *dynamicApplicationListenerProvider;
@property(nonatomic, strong) NSMutableArray<id<LAListener>> *registeredListeners;

@property(nonatomic, assign) BOOL eventSourcesStarted;
@property(nonatomic, strong, readwrite) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readwrite) LATLockStateEventSource *lockStateEventSource;
@property(nonatomic, strong, readwrite) LATPowerStateEventSource *powerStateEventSource;
@property(nonatomic, strong, readwrite) LATMediaEventSource *mediaEventSource;

@end

@implementation LATBuiltInRegistry

- (instancetype)initWithActivator:(LAActivator *)activator {
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _applicationLauncher = [[LATApplicationLauncher alloc] init];
        _registeredListeners = [[NSMutableArray alloc] init];
        LARuntimeContext *runtimeContext = [activator la_runtimeContext];
        NSParameterAssert(runtimeContext);
        _runtimeStateSource = [[LATRuntimeStateSource alloc] initWithRuntimeContext:runtimeContext];
        _lockStateEventSource = [[LATLockStateEventSource alloc] initWithRuntimeStateSource:_runtimeStateSource];
        _powerStateEventSource = [[LATPowerStateEventSource alloc] init];
        _mediaEventSource = [[LATMediaEventSource alloc] init];

        [self registerBuiltInListenersWithActivator:activator];
    }
    return self;
}

- (void)startEventSources {
    if (self.eventSourcesStarted) {
        return;
    }
    self.eventSourcesStarted = YES;

    [self.runtimeStateSource start];
    [self.lockStateEventSource start];
    [self.powerStateEventSource start];
    [self.mediaEventSource start];
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
            @"RegistrantClass" : LATTelephonyActionListener.class,
            @"MissingMetadataReason" : @"selector metadata is missing or mismatched",
        },
    ];
}

- (id<LAListener>)createListenerForRegistrantClass:(Class<LATBuiltInListenerRegistrant>)registrantClass {
    if (registrantClass == LATSystemActionListener.class) {
        return [[LATSystemActionListener alloc] initWithLauncher:self.applicationLauncher registry:self];
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
