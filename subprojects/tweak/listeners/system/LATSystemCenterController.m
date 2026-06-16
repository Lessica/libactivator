//
//  LATSystemCenterController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemCenterController.h"

#import "LATRuntimeStateSource.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (BOOL)isControlCenterVisible;
- (BOOL)showControlCenter:(BOOL)show;
- (BOOL)isNotificationCenterVisible;
- (void)showNotificationCenter;
- (BOOL)showNotificationCenter:(BOOL)show;
- (void)hideNotificationCenter;
- (void)toggleNotificationCenter;
@end

@interface CCUIModuleCollectionViewController : UIViewController
- (void)dismissExpandedModuleAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)expandModuleWithIdentifier:(id)identifier;
@end

static NSString *const LATNowPlayingControlCenterModuleIdentifier = @"com.apple.mediaremote.controlcenter.nowplaying";
static __weak UIViewController *gModuleCollectionViewController = nil;
static BOOL gPendingNowPlayingControlsExpansion = NO;

@interface LATSystemCenterController ()
@property(nonatomic, weak, nullable) LATRuntimeStateSource *runtimeStateSource;
+ (BOOL)expandPendingNowPlayingControlsIfPossibleForListenerName:(nullable NSString *)listenerName;
- (void)showNowPlayingControlsWithPoweredDisplayForListenerName:(NSString *)listenerName;
@end

@implementation LATSystemCenterController

- (instancetype)initWithRuntimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource {
    self = [super init];
    if (self) {
        _runtimeStateSource = runtimeStateSource;
    }
    return self;
}

+ (void)noteModuleCollectionViewControllerDidLoad:(UIViewController *)viewController {
    gModuleCollectionViewController = viewController;
}

+ (void)noteModuleCollectionViewControllerWillAppear:(UIViewController *)viewController {
    gModuleCollectionViewController = viewController;
    [self expandPendingNowPlayingControlsIfPossibleForListenerName:nil];
}

+ (BOOL)expandPendingNowPlayingControlsIfPossibleForListenerName:(nullable NSString *)listenerName {
    if (!gPendingNowPlayingControlsExpansion) {
        return NO;
    }

    UIViewController *viewController = gModuleCollectionViewController;
    if (![viewController respondsToSelector:@selector(expandModuleWithIdentifier:)]) {
        HBLogWarn(@"Control Center module collection controller is unavailable for system action %@",
                  listenerName ?: @"");
        return NO;
    }

    gPendingNowPlayingControlsExpansion = NO;
    CCUIModuleCollectionViewController *moduleCollectionViewController =
        (CCUIModuleCollectionViewController *)viewController;
    void (^expandBlock)(void) = ^{
        [moduleCollectionViewController expandModuleWithIdentifier:LATNowPlayingControlCenterModuleIdentifier];
        HBLogDebug(@"Requested Control Center Now Playing module expansion for system action %@", listenerName ?: @"");
    };

    if ([moduleCollectionViewController respondsToSelector:@selector(dismissExpandedModuleAnimated:completion:)]) {
        [moduleCollectionViewController dismissExpandedModuleAnimated:NO completion:expandBlock];
    } else {
        expandBlock();
    }
    return YES;
}

- (BOOL)activateControlCenterForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    BOOL visible = NO;
    if ([server respondsToSelector:@selector(isControlCenterVisible)]) {
        visible = [server isControlCenterVisible];
    }
    if (![server respondsToSelector:@selector(showControlCenter:)]) {
        HBLogError(@"AXSpringBoardServer cannot toggle Control Center for system action %@", listenerName ?: @"");
        return YES;
    }
    if (![server showControlCenter:!visible]) {
        HBLogWarn(@"AXSpringBoardServer refused to toggle Control Center for system action %@", listenerName ?: @"");
    }
    return YES;
}

- (BOOL)showNowPlayingControlsForListenerName:(NSString *)listenerName {
    dispatch_block_t showBlock = ^{
        [self showNowPlayingControlsWithPoweredDisplayForListenerName:listenerName];
    };

    LATRuntimeStateSource *runtimeStateSource = self.runtimeStateSource;
    if (!runtimeStateSource) {
        HBLogWarn(@"Runtime state source is unavailable for Now Playing controls action %@", listenerName ?: @"");
        showBlock();
        return YES;
    }

    if ([runtimeStateSource screenIsOn]) {
        showBlock();
        return YES;
    }

    if (![runtimeStateSource wakeScreenForReason:(listenerName ?: @"libactivator.now-playing-controls")
                                      completion:showBlock]) {
        HBLogWarn(@"Screen wake was not started for Now Playing controls action %@", listenerName ?: @"");
        showBlock();
        return YES;
    }
    return YES;
}

- (void)showNowPlayingControlsWithPoweredDisplayForListenerName:(NSString *)listenerName {
    gPendingNowPlayingControlsExpansion = YES;
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    BOOL visible = NO;
    if ([server respondsToSelector:@selector(isControlCenterVisible)]) {
        visible = [server isControlCenterVisible];
    }

    if (![server respondsToSelector:@selector(showControlCenter:)]) {
        HBLogError(@"AXSpringBoardServer cannot show Control Center for system action %@", listenerName ?: @"");
        return;
    }

    if (!visible && ![server showControlCenter:YES]) {
        HBLogWarn(@"AXSpringBoardServer refused to show Control Center for system action %@", listenerName ?: @"");
        return;
    }

    if (visible) {
        [self.class expandPendingNowPlayingControlsIfPossibleForListenerName:listenerName];
    }
}

- (BOOL)activateNotificationCenterForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    BOOL visibilityKnown = [server respondsToSelector:@selector(isNotificationCenterVisible)];
    BOOL visible = visibilityKnown ? [server isNotificationCenterVisible] : NO;
    if (visibilityKnown && visible) {
        if ([server respondsToSelector:@selector(hideNotificationCenter)]) {
            [server hideNotificationCenter];
            return YES;
        }
        if ([server respondsToSelector:@selector(showNotificationCenter:)]) {
            if (![server showNotificationCenter:NO]) {
                HBLogWarn(@"AXSpringBoardServer refused to hide Notification Center for system action %@",
                          listenerName ?: @"");
            }
            return YES;
        }
        if ([server respondsToSelector:@selector(toggleNotificationCenter)]) {
            [server toggleNotificationCenter];
            return YES;
        }
        HBLogError(@"AXSpringBoardServer cannot hide Notification Center for system action %@", listenerName ?: @"");
        return YES;
    }
    if ([server respondsToSelector:@selector(showNotificationCenter:)]) {
        if (![server showNotificationCenter:YES]) {
            HBLogWarn(@"AXSpringBoardServer refused to show Notification Center for system action %@",
                      listenerName ?: @"");
        }
        return YES;
    }
    if ([server respondsToSelector:@selector(showNotificationCenter)]) {
        [server showNotificationCenter];
        return YES;
    }
    if ([server respondsToSelector:@selector(toggleNotificationCenter)]) {
        [server toggleNotificationCenter];
        return YES;
    }
    HBLogError(@"AXSpringBoardServer cannot toggle Notification Center for system action %@", listenerName ?: @"");
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

@end
