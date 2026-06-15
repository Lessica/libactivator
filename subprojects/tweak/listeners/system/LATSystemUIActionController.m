//
//  LATSystemUIActionController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemUIActionController.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (void)presentPowerDownTransientOverlay;
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

@interface UIApplication (LATSystemUIActionController)
- (void)_takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshot;
@end

@implementation LATSystemUIActionController

- (BOOL)activateSwitcherForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        SBSwitcherController *switcherController = [self activeDisplaySwitcherController];
        if ([switcherController respondsToSelector:@selector(toggleMainSwitcherWithSource:animated:)]) {
            if (![switcherController toggleMainSwitcherWithSource:0x14 animated:YES]) {
                HBLogWarn(@"SBSwitcherController refused to toggle main switcher for system action %@",
                          listenerName ?: @"");
            }
            return;
        }
        if ([switcherController respondsToSelector:@selector(toggleMainSwitcherNoninteractivelyWithSource:animated:)]) {
            if (![switcherController toggleMainSwitcherNoninteractivelyWithSource:0x14 animated:YES]) {
                HBLogWarn(@"SBSwitcherController refused to toggle main switcher noninteractively for system action %@",
                          listenerName ?: @"");
            }
            return;
        }

        SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
        if ([legacySwitcher respondsToSelector:@selector(activateMainSwitcherNoninteractivelyWithSource:animated:)]) {
            [legacySwitcher activateMainSwitcherNoninteractivelyWithSource:1 animated:YES];
            return;
        }

        HBLogError(@"SpringBoard cannot activate switcher for system action %@", listenerName ?: @"");
    }];
}

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

- (BOOL)editScreenshotForListenerName:(NSString *)listenerName {
    return [self performOnMainQueueForListenerName:listenerName block:^{
        UIApplication *application = UIApplication.sharedApplication;
        if ([application respondsToSelector:@selector(_takeScreenshotAndEdit:)]) {
            [application _takeScreenshotAndEdit:YES];
        } else if ([application respondsToSelector:@selector(takeScreenshotAndEdit:)]) {
            [application takeScreenshotAndEdit:YES];
        } else if ([application respondsToSelector:@selector(takeScreenshot)]) {
            [application takeScreenshot];
        } else {
            HBLogError(@"SpringBoard cannot edit screenshot for system action %@", listenerName ?: @"");
        }
    }];
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

- (BOOL)performOnMainQueueForListenerName:(NSString *)listenerName block:(dispatch_block_t)block {
    if (!block) {
        return NO;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    return YES;
}

@end
