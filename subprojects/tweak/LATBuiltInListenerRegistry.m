//
//  LATBuiltInListenerRegistry.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInListenerRegistry.h"

#import "LATBuiltInListenerRegistrant.h"
#import "LATHardwareActionListener.h"
#import "LATNothingListener.h"
#import "LATTelephonyActionListener.h"
#import "LATSystemActionListener.h"
#import "LATURLActionListener.h"

#import <HBLog.h>

static __weak SBVolumeControl *gCapturedVolumeControl = nil;
static __weak SBRingerControl *gCapturedRingerControl = nil;

@implementation LATBuiltInListenerRegistry

+ (SBVolumeControl *)volumeControlInstance {
    return gCapturedVolumeControl;
}

+ (void)setVolumeControlInstance:(SBVolumeControl *)volumeControlInstance {
    gCapturedVolumeControl = volumeControlInstance;
}

+ (SBRingerControl *)ringerControlInstance {
    return gCapturedRingerControl;
}

+ (void)setRingerControlInstance:(SBRingerControl *)ringerControlInstance {
    gCapturedRingerControl = ringerControlInstance;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)la_builtInListenerFactoryConfigurations {
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

+ (id<LAListener>)la_createListenerForRegistrantClass:(Class<LATBuiltInListenerRegistrant>)registrantClass {
    return [[(Class)registrantClass alloc] init];
}

+ (void)la_registerListener:(id<LAListener>)listener
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

+ (void)registerWithActivator:(LAActivator *)activator {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        LATNothingListener *nothingListener = [[LATNothingListener alloc] init];
        [activator registerListener:nothingListener forName:@"libactivator.system.nothing"];

        for (NSDictionary<NSString *, id> *configuration in [self la_builtInListenerFactoryConfigurations]) {
            Class<LATBuiltInListenerRegistrant> registrantClass = configuration[@"RegistrantClass"];
            NSString *missingMetadataReason = configuration[@"MissingMetadataReason"];
            if (!registrantClass || missingMetadataReason.length == 0) {
                continue;
            }

            id<LAListener> listener = [self la_createListenerForRegistrantClass:registrantClass];
            if (!listener) {
                continue;
            }

            [self la_registerListener:listener
                      registrantClass:registrantClass
                            activator:activator
                missingMetadataReason:missingMetadataReason];
        }
    });
}

@end
