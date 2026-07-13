//
//  LATSystemSwitcherController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemSwitcherController.h"

#import "LATRuntimeStateSource.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (BOOL)isAppSwitcherVisible;
- (void)openAppSwitcher;
- (void)dismissAppSwitcher;
@end

@interface SBDisplayItem : NSObject
@property(nonatomic, copy, readonly, nullable) NSString *bundleIdentifier;
@end

@interface SBAppLayout : NSObject
@property(nonatomic, copy, readonly) NSDictionary<NSNumber *, SBDisplayItem *> *rolesToLayoutItemsMap;
- (NSArray<SBDisplayItem *> *)allItems;
@end

@interface SBSwitcherController : NSObject
- (BOOL)isAnySwitcherVisible;
- (BOOL)isMainSwitcherVisible;
- (BOOL)toggleMainSwitcherWithSource:(long long)source animated:(BOOL)animated;
- (BOOL)toggleMainSwitcherNoninteractivelyWithSource:(long long)source animated:(BOOL)animated;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (BOOL)isAnySwitcherVisible;
- (nullable SBSwitcherController *)_activeDisplaySwitcherController;
- (NSArray<SBAppLayout *> *)recentAppLayouts;
- (void)_deleteAppLayoutsMatchingBundleIdentifier:(NSString *)identifier;
- (void)_removeAppLayout:(SBAppLayout *)layout forReason:(long long)reason;
- (BOOL)deleteAppLayoutForDisplayItem:(SBDisplayItem *)item;
- (void)removeAppLayoutForDisplayItem:(SBDisplayItem *)item shouldDestroyScene:(BOOL)destroyScene;
@end

@interface SBMainSwitcherViewController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isMainSwitcherVisible;
- (BOOL)activateMainSwitcherNoninteractivelyWithSource:(long long)source animated:(BOOL)animated;
- (NSArray<SBAppLayout *> *)recentAppLayouts;
- (void)_deleteAppLayoutsMatchingBundleIdentifier:(NSString *)identifier;
- (void)_deleteAppLayout:(SBAppLayout *)layout forReason:(long long)reason;
@end

@interface LATSystemSwitcherController ()
@property(nonatomic, weak, nullable) id<LATNowPlayingProviding> nowPlayingProvider;
@property(nonatomic, weak, nullable) LATRuntimeStateSource *runtimeStateSource;
@end

@implementation LATSystemSwitcherController

#pragma mark - Lifecycle

- (instancetype)initWithNowPlayingProvider:(id<LATNowPlayingProviding>)nowPlayingProvider
                        runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource {
    self = [super init];
    if (self) {
        _nowPlayingProvider = nowPlayingProvider;
        _runtimeStateSource = runtimeStateSource;
    }
    return self;
}

#pragma mark - Public Actions

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
        BOOL toggled = [switcherController toggleMainSwitcherWithSource:0x14 animated:YES];
        if (!toggled) {
            HBLogWarn(@"SBSwitcherController refused to toggle main switcher for system action %@",
                      listenerName ?: @"");
        }
        return toggled;
    }
    if ([switcherController respondsToSelector:@selector(toggleMainSwitcherNoninteractivelyWithSource:animated:)]) {
        BOOL toggled = [switcherController toggleMainSwitcherNoninteractivelyWithSource:0x14 animated:YES];
        if (!toggled) {
            HBLogWarn(@"SBSwitcherController refused to toggle main switcher noninteractively for system action %@",
                      listenerName ?: @"");
        }
        return toggled;
    }

    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    if ([legacySwitcher respondsToSelector:@selector(activateMainSwitcherNoninteractivelyWithSource:animated:)]) {
        [legacySwitcher activateMainSwitcherNoninteractivelyWithSource:1 animated:YES];
        return YES;
    }

    HBLogError(@"SpringBoard cannot activate switcher for system action %@", listenerName ?: @"");
    return NO;
}

- (BOOL)clearSwitcherForListenerName:(NSString *)listenerName {
    return [self clearSwitcherForListenerName:listenerName skipsNowPlayingApplication:YES];
}

- (BOOL)clearSwitcherForListenerName:(NSString *)listenerName
          skipsNowPlayingApplication:(BOOL)skipsNowPlayingApplication {
    NSString *listenerNameToClear = [listenerName copy] ?: @"";
    if (skipsNowPlayingApplication) {
        id<LATNowPlayingProviding> nowPlayingProvider = self.nowPlayingProvider;
        if (!nowPlayingProvider) {
            HBLogError(@"Unable to clear switcher for system action %@ because the media event source is unavailable",
                       listenerNameToClear ?: @"");
            return NO;
        }

        return [nowPlayingProvider
            requestNowPlayingApplicationDisplayIdentifierWithCompletion:^(NSString *displayIdentifier) {
                [self prepareClearSwitcherForListenerName:listenerNameToClear
                              nowPlayingDisplayIdentifier:displayIdentifier];
            }];
    }

    [self openSwitcherForClearingWithListenerName:listenerNameToClear];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self clearSwitcherForListenerName:listenerNameToClear excludingDisplayIdentifier:nil];
    });
    return YES;
}

#pragma mark - Clear Switcher Flow

- (void)prepareClearSwitcherForListenerName:(NSString *)listenerName
                nowPlayingDisplayIdentifier:(NSString *)nowPlayingDisplayIdentifier {
    NSArray<SBAppLayout *> *appLayouts = [[self currentSwitcherAppLayouts] copy];
    if (![self shouldOpenSwitcherBeforeClearingAppLayouts:appLayouts
                              nowPlayingDisplayIdentifier:nowPlayingDisplayIdentifier]) {
        if ([self appLayouts:appLayouts containDisplayIdentifierOtherThan:nowPlayingDisplayIdentifier]) {
            [self clearSwitcherForListenerName:listenerName excludingDisplayIdentifier:nowPlayingDisplayIdentifier];
        }
        return;
    }

    [self openSwitcherForClearingWithListenerName:listenerName];
    NSString *identifierToSkip = [nowPlayingDisplayIdentifier copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self clearSwitcherForListenerName:listenerName excludingDisplayIdentifier:identifierToSkip];
    });
}

- (void)clearSwitcherForListenerName:(NSString *)listenerName
          excludingDisplayIdentifier:(NSString *)excludedIdentifier {
    NSArray<SBAppLayout *> *appLayouts = [[self currentSwitcherAppLayouts] copy];
    if (appLayouts.count == 0) {
        HBLogWarn(@"SpringBoard returned no app switcher layouts for system action %@", listenerName ?: @"");
        return;
    }

    NSUInteger removedCount = 0;
    for (SBAppLayout *appLayout in appLayouts) {
        NSString *identifier = [self displayIdentifierForAppLayout:appLayout];
        if (identifier.length > 0 && excludedIdentifier.length > 0 && [identifier isEqualToString:excludedIdentifier]) {
            continue;
        }
        if ([self removeAppLayout:appLayout displayIdentifier:identifier listenerName:listenerName]) {
            removedCount++;
        }
    }

    if (removedCount == 0) {
        HBLogWarn(@"SpringBoard did not remove any app switcher layouts for system action %@", listenerName ?: @"");
    }
}

- (BOOL)shouldOpenSwitcherBeforeClearingAppLayouts:(NSArray<SBAppLayout *> *)appLayouts
                       nowPlayingDisplayIdentifier:(NSString *)nowPlayingDisplayIdentifier {
    if (appLayouts.count == 0) {
        return NO;
    }

    if (nowPlayingDisplayIdentifier.length > 0) {
        NSString *currentApplicationIdentifier = [self currentApplicationDisplayIdentifier];
        if ([currentApplicationIdentifier isEqualToString:nowPlayingDisplayIdentifier]) {
            return NO;
        }

        if (![self appLayouts:appLayouts containDisplayIdentifierOtherThan:nowPlayingDisplayIdentifier]) {
            return NO;
        }
    }

    return YES;
}

#pragma mark - Switcher Presentation

- (void)openSwitcherForClearingWithListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    if ([server respondsToSelector:@selector(isAppSwitcherVisible)] && [server isAppSwitcherVisible]) {
        return;
    }
    if ([server respondsToSelector:@selector(openAppSwitcher)]) {
        [server openAppSwitcher];
        return;
    }

    if ([self isSwitcherVisible]) {
        return;
    }

    SBSwitcherController *switcherController = [self activeDisplaySwitcherController];
    if ([switcherController respondsToSelector:@selector(toggleMainSwitcherWithSource:animated:)]) {
        if (![switcherController toggleMainSwitcherWithSource:0x14 animated:YES]) {
            HBLogWarn(@"SBSwitcherController refused to open main switcher for system action %@", listenerName ?: @"");
        }
        return;
    }
    if ([switcherController respondsToSelector:@selector(toggleMainSwitcherNoninteractivelyWithSource:animated:)]) {
        if (![switcherController toggleMainSwitcherNoninteractivelyWithSource:0x14 animated:YES]) {
            HBLogWarn(@"SBSwitcherController refused to open main switcher noninteractively for system action %@",
                      listenerName ?: @"");
        }
        return;
    }

    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    if ([legacySwitcher respondsToSelector:@selector(activateMainSwitcherNoninteractivelyWithSource:animated:)]) {
        [legacySwitcher activateMainSwitcherNoninteractivelyWithSource:1 animated:YES];
        return;
    }

    HBLogError(@"SpringBoard cannot open switcher before clearing for system action %@", listenerName ?: @"");
}

- (BOOL)isSwitcherVisible {
    SBMainSwitcherControllerCoordinator *coordinator = [self mainSwitcherControllerCoordinatorIfExists];
    if ([coordinator respondsToSelector:@selector(isAnySwitcherVisible)] && [coordinator isAnySwitcherVisible]) {
        return YES;
    }

    SBSwitcherController *switcherController = [self activeDisplaySwitcherController];
    if ([switcherController respondsToSelector:@selector(isAnySwitcherVisible)] &&
        [switcherController isAnySwitcherVisible]) {
        return YES;
    }
    if ([switcherController respondsToSelector:@selector(isMainSwitcherVisible)] &&
        [switcherController isMainSwitcherVisible]) {
        return YES;
    }

    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    return
        [legacySwitcher respondsToSelector:@selector(isMainSwitcherVisible)] && [legacySwitcher isMainSwitcherVisible];
}

#pragma mark - App Layout Collection

- (NSArray<SBAppLayout *> *)currentSwitcherAppLayouts {
    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    if ([legacySwitcher respondsToSelector:@selector(recentAppLayouts)]) {
        return [legacySwitcher recentAppLayouts];
    }

    SBMainSwitcherControllerCoordinator *coordinator = [self mainSwitcherControllerCoordinatorIfExists];
    if ([coordinator respondsToSelector:@selector(recentAppLayouts)]) {
        return [coordinator recentAppLayouts];
    }

    return @[];
}

- (BOOL)appLayouts:(NSArray<SBAppLayout *> *)appLayouts
    containDisplayIdentifierOtherThan:(NSString *)displayIdentifier {
    for (SBAppLayout *appLayout in appLayouts) {
        NSString *candidateIdentifier = [self displayIdentifierForAppLayout:appLayout];
        if (candidateIdentifier.length == 0) {
            continue;
        }
        if (displayIdentifier.length == 0 || ![candidateIdentifier isEqualToString:displayIdentifier]) {
            return YES;
        }
    }
    return NO;
}

- (nullable NSString *)displayIdentifierForAppLayout:(SBAppLayout *)appLayout {
    SBDisplayItem *displayItem = [self primaryDisplayItemForAppLayout:appLayout];
    return displayItem.bundleIdentifier;
}

- (nullable SBDisplayItem *)primaryDisplayItemForAppLayout:(SBAppLayout *)appLayout {
    if ([appLayout respondsToSelector:@selector(allItems)]) {
        for (SBDisplayItem *displayItem in [appLayout allItems]) {
            if (displayItem.bundleIdentifier.length > 0) {
                return displayItem;
            }
        }
    }

    if ([appLayout respondsToSelector:@selector(rolesToLayoutItemsMap)]) {
        for (SBDisplayItem *displayItem in appLayout.rolesToLayoutItemsMap.allValues) {
            if (displayItem.bundleIdentifier.length > 0) {
                return displayItem;
            }
        }
    }

    return nil;
}

#pragma mark - App Layout Removal

- (BOOL)removeAppLayout:(SBAppLayout *)appLayout
      displayIdentifier:(NSString *)displayIdentifier
           listenerName:(NSString *)listenerName {
    SBMainSwitcherViewController *legacySwitcher = [self legacyMainSwitcherViewController];
    if (displayIdentifier.length > 0 &&
        [legacySwitcher respondsToSelector:@selector(_deleteAppLayoutsMatchingBundleIdentifier:)]) {
        [legacySwitcher _deleteAppLayoutsMatchingBundleIdentifier:displayIdentifier];
        return YES;
    }
    if ([legacySwitcher respondsToSelector:@selector(_deleteAppLayout:forReason:)]) {
        [legacySwitcher _deleteAppLayout:appLayout forReason:1];
        return YES;
    }

    SBMainSwitcherControllerCoordinator *coordinator = [self mainSwitcherControllerCoordinatorIfExists];
    if (displayIdentifier.length > 0 &&
        [coordinator respondsToSelector:@selector(_deleteAppLayoutsMatchingBundleIdentifier:)]) {
        [coordinator _deleteAppLayoutsMatchingBundleIdentifier:displayIdentifier];
        return YES;
    }

    SBDisplayItem *displayItem = [self primaryDisplayItemForAppLayout:appLayout];
    if (displayItem && [coordinator respondsToSelector:@selector(deleteAppLayoutForDisplayItem:)]) {
        return [coordinator deleteAppLayoutForDisplayItem:displayItem];
    }
    if (displayItem && [coordinator respondsToSelector:@selector(removeAppLayoutForDisplayItem:shouldDestroyScene:)]) {
        [coordinator removeAppLayoutForDisplayItem:displayItem shouldDestroyScene:YES];
        return YES;
    }
    if ([coordinator respondsToSelector:@selector(_removeAppLayout:forReason:)]) {
        [coordinator _removeAppLayout:appLayout forReason:1];
        return YES;
    }

    HBLogError(@"SpringBoard cannot remove app switcher layout %@ for system action %@", displayIdentifier ?: @"",
               listenerName ?: @"");
    return NO;
}

#pragma mark - SpringBoard Accessors

- (nullable NSString *)currentApplicationDisplayIdentifier {
    LATRuntimeStateSource *runtimeStateSource = self.runtimeStateSource;
    [runtimeStateSource refreshForegroundDisplayIdentifier];
    return [runtimeStateSource displayIdentifierForCurrentApplication];
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

- (nullable SBMainSwitcherControllerCoordinator *)mainSwitcherControllerCoordinatorIfExists {
    Class coordinatorClass = NSClassFromString(@"SBMainSwitcherControllerCoordinator");
    SBMainSwitcherControllerCoordinator *coordinator = nil;
    if ([coordinatorClass respondsToSelector:@selector(sharedInstanceIfExists)]) {
        coordinator = [(id)coordinatorClass sharedInstanceIfExists];
    }
    if (!coordinator && [coordinatorClass respondsToSelector:@selector(sharedInstance)]) {
        coordinator = [(id)coordinatorClass sharedInstance];
    }
    return coordinator;
}

@end
