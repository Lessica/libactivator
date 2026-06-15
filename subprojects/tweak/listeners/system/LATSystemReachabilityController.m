//
//  LATSystemReachabilityController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemReachabilityController.h"

#import <HBLog.h>

@interface AXSpringBoardServerHelper : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)server;
- (BOOL)isReachabilityActive;
- (void)setReachabilityActive:(BOOL)active;
@end

@implementation LATSystemReachabilityController

- (BOOL)activateReachabilityForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        AXSpringBoardServerHelper *helper = [self axSpringBoardServerHelperForListenerName:listenerName];
        if (![helper respondsToSelector:@selector(isReachabilityActive)] ||
            ![helper respondsToSelector:@selector(setReachabilityActive:)]) {
            HBLogError(@"AXSpringBoardServerHelper cannot toggle Reachability for system action %@",
                       listenerName ?: @"");
            return;
        }
        [helper setReachabilityActive:![helper isReachabilityActive]];
    }];
}

- (nullable AXSpringBoardServerHelper *)axSpringBoardServerHelperForListenerName:(NSString *)listenerName {
    Class helperClass = NSClassFromString(@"AXSpringBoardServerHelper");
    if (!helperClass) {
        HBLogError(@"AXSpringBoardServerHelper is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    if ([helperClass respondsToSelector:@selector(sharedInstance)]) {
        return [(id)helperClass sharedInstance];
    }
    if ([helperClass respondsToSelector:@selector(server)]) {
        return [(id)helperClass server];
    }
    if ([helperClass instancesRespondToSelector:@selector(init)]) {
        return [[helperClass alloc] init];
    }
    HBLogError(@"AXSpringBoardServerHelper cannot be created for system action %@", listenerName ?: @"");
    return nil;
}

@end
