//
//  LATBuiltInListenerRegistry.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInListenerRegistry.h"

#import "LATNothingListener.h"
#import "LATURLActionListener.h"

#import <HBLog.h>

@implementation LATBuiltInListenerRegistry

+ (void)registerBuiltInListenersWithActivator:(LAActivator *)activator {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LATNothingListener *nothingListener = [[LATNothingListener alloc] init];
        [activator registerListener:nothingListener forName:@"libactivator.system.nothing"];

        LATURLActionListener *urlActionListener = [[LATURLActionListener alloc] init];
        for (NSString *listenerName in [self urlActionListenerNames]) {
            if ([self listenerHasURLMetadata:listenerName activator:activator]) {
                [activator registerListener:urlActionListener forName:listenerName];
            } else {
                HBLogWarn(@"Skipping URL action %@ because URL metadata is missing", listenerName);
            }
        }
    });
}

+ (NSArray *)urlActionListenerNames {
    return @[
        @"libactivator.clock.alarm",
        @"libactivator.clock.stopwatch",
        @"libactivator.clock.timer",
        @"libactivator.clock.world-clock",
        @"libactivator.settings.about",
        @"libactivator.settings.accessibility",
        @"libactivator.settings.auto-lock",
        @"libactivator.settings.background-app-refresh",
        @"libactivator.settings.battery",
        @"libactivator.settings.bluetooth",
        @"libactivator.settings.carplay",
        @"libactivator.settings.cellular",
        @"libactivator.settings.control-center",
        @"libactivator.settings.date-time",
        @"libactivator.settings.display",
        @"libactivator.settings.do-not-disturb",
        @"libactivator.settings.facetime",
        @"libactivator.settings.game-center",
        @"libactivator.settings.general",
        @"libactivator.settings.handoff",
        @"libactivator.settings.icloud",
        @"libactivator.settings.international",
        @"libactivator.settings.keyboard",
        @"libactivator.settings.location-services",
        @"libactivator.settings.mail",
        @"libactivator.settings.managed-configuration",
        @"libactivator.settings.maps",
        @"libactivator.settings.messages",
        @"libactivator.settings.music",
        @"libactivator.settings.notes",
        @"libactivator.settings.notifications",
        @"libactivator.settings.passcode",
        @"libactivator.settings.phone",
        @"libactivator.settings.photos",
        @"libactivator.settings.privacy",
        @"libactivator.settings.reminders",
        @"libactivator.settings.safari",
        @"libactivator.settings.sounds",
        @"libactivator.settings.store",
        @"libactivator.settings.tethering",
        @"libactivator.settings.virtual-assistant",
        @"libactivator.settings.vpn",
        @"libactivator.settings.wallpaper",
        @"libactivator.settings.wifi",
    ];
}

+ (BOOL)listenerHasURLMetadata:(NSString *)listenerName activator:(LAActivator *)activator {
    id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
    if ([url isKindOfClass:NSString.class] && [url length] > 0) {
        return YES;
    }
    id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
    return [urls isKindOfClass:NSArray.class] && [urls count] > 0;
}

@end
