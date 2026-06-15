//
//  LATSystemPowerMenuController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemPowerMenuController.h"

#import <HBLog.h>

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (void)presentPowerDownTransientOverlay;
@end

@implementation LATSystemPowerMenuController

- (BOOL)showPowerMenuForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        Class workspaceClass = NSClassFromString(@"SBMainWorkspace");
        SBMainWorkspace *workspace = nil;
        if ([workspaceClass respondsToSelector:@selector(sharedInstanceIfExists)]) {
            workspace = [(id)workspaceClass sharedInstanceIfExists];
        }
        if (!workspace && [workspaceClass respondsToSelector:@selector(sharedInstance)]) {
            workspace = [(id)workspaceClass sharedInstance];
        }

        if (![workspace respondsToSelector:@selector(presentPowerDownTransientOverlay)]) {
            HBLogError(@"SBMainWorkspace cannot present power menu for system action %@", listenerName ?: @"");
            return;
        }
        [workspace presentPowerDownTransientOverlay];
    }];
}

@end
