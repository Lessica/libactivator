//
//  LATBuiltInListenerRegistry.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInListenerRegistry.h"

#import "LATNothingListener.h"

@implementation LATBuiltInListenerRegistry

+ (void)registerBuiltInListenersWithActivator:(LAActivator *)activator {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LATNothingListener *nothingListener = [[LATNothingListener alloc] init];
        [activator registerListener:nothingListener forName:@"libactivator.system.nothing"];
    });
}

@end
