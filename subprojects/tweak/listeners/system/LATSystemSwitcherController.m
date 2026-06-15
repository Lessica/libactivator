//
//  LATSystemSwitcherController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemSwitcherController.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (BOOL)isAppSwitcherVisible;
- (void)openAppSwitcher;
- (void)dismissAppSwitcher;
@end

@interface SBSwitcherController : NSObject
- (BOOL)toggleMainSwitcherWithSource:(long long)source animated:(BOOL)animated;
- (BOOL)toggleMainSwitcherNoninteractivelyWithSource:(long long)source animated:(BOOL)animated;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (nullable SBSwitcherController *)_activeDisplaySwitcherController;
@end

@interface SBMainSwitcherViewController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)activateMainSwitcherNoninteractivelyWithSource:(long long)source animated:(BOOL)animated;
@end

@implementation LATSystemSwitcherController

- (BOOL)activateSwitcherForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    if ([server respondsToSelector:@selector(isAppSwitcherVisible)] && [server isAppSwitcherVisible]) {
        if ([server respondsToSelector:@selector(dismissAppSwitcher)]) {
            [server dismissAppSwitcher];
            return YES;
        }
    } else if ([server respondsToSelector:@selector(openAppSwitcher)]) {
        [server openAppSwitcher];
        return YES;
    }

    SBSwitcherController *switcherController = [self activeDisplaySwitcherController];
    if ([switcherController respondsToSelector:@selector(toggleMainSwitcherWithSource:animated:)]) {
        if (![switcherController toggleMainSwitcherWithSource:0x14 animated:YES]) {
            HBLogWarn(@"SBSwitcherController refused to toggle main switcher for system action %@",
                      listenerName ?: @"");
        }
        return YES;
    }
    if ([switcherController respondsToSelector:@selector(toggleMainSwitcherNoninteractivelyWithSource:animated:)]) {
        if (![switcherController toggleMainSwitcherNoninteractivelyWithSource:0x14 animated:YES]) {
            HBLogWarn(@"SBSwitcherController refused to toggle main switcher noninteractively for system action %@",
                      listenerName ?: @"");
        }
        return YES;
    }

    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    if ([legacySwitcher respondsToSelector:@selector(activateMainSwitcherNoninteractivelyWithSource:animated:)]) {
        [legacySwitcher activateMainSwitcherNoninteractivelyWithSource:1 animated:YES];
        return YES;
    }

    HBLogError(@"SpringBoard cannot activate switcher for system action %@", listenerName ?: @"");
    return YES;
}

- (nullable AXSpringBoardServer *)axSpringBoardServerForListenerName:(NSString *)listenerName {
    Class serverClass = NSClassFromString(@"AXSpringBoardServer");
    if (![serverClass respondsToSelector:@selector(server)]) {
        HBLogError(@"AXSpringBoardServer is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(id)serverClass server];
}

- (nullable SBSwitcherController *)activeDisplaySwitcherController {
    Class coordinatorClass = NSClassFromString(@"SBMainSwitcherControllerCoordinator");
    SBMainSwitcherControllerCoordinator *coordinator = nil;
    if ([coordinatorClass respondsToSelector:@selector(sharedInstanceIfExists)]) {
        coordinator = [(id)coordinatorClass sharedInstanceIfExists];
    }
    if (!coordinator && [coordinatorClass respondsToSelector:@selector(sharedInstance)]) {
        coordinator = [(id)coordinatorClass sharedInstance];
    }
    if (![coordinator respondsToSelector:@selector(_activeDisplaySwitcherController)]) {
        return nil;
    }
    return [coordinator _activeDisplaySwitcherController];
}

- (nullable SBMainSwitcherViewController *)legacyMainSwitcherViewController {
    Class switcherClass = NSClassFromString(@"SBMainSwitcherViewController");
    if (![switcherClass respondsToSelector:@selector(sharedInstance)]) {
        return nil;
    }
    return [(id)switcherClass sharedInstance];
}

@end
