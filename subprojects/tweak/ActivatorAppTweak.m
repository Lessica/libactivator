//
//  ActivatorAppTweak.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <notify.h>

CHDeclareClass(UIApplication);
CHDeclareClass(CAMViewfinderViewController);
CHDeclareClass(PhoneApplication);
CHDeclareClass(PhoneTabBarController);

@interface UIApplication (LATAppTweakPrivate)
- (nullable UIViewController *)rootViewController;
- (void)setWantsVolumeButtonEvents:(BOOL)wantsVolumeButtonEvents;
@end

@interface MPRootViewController : UIViewController
- (nullable UIViewController *)baseViewController;
@end

@interface UIViewController (LATPhoneAppPrivate)
- (nullable UIViewController *)tabBarViewController;
@end

@interface PhoneTabBarController : UITabBarController
- (nullable UIViewController *)keypadViewController;
- (NSInteger)tabTypeForViewController:(UIViewController *)viewController;
- (void)switchToTab:(NSInteger)tabType;
@end

@interface CAMViewfinderViewController : UIViewController
- (void)_updateEnabledControlsWithReason:(NSString *)reason forceLog:(BOOL)forceLog;
@end

static NSString *const LATPhoneKeypadURLString = @"mobilephone-recents:keypad";
static const char *LATCameraReadyNotification = "libactivator.camera.ready";
static const CFTimeInterval LATCameraReadyNotificationThrottle = 0.25;
static const NSTimeInterval LATCameraReadyNotificationDelay = 0.6;

// Camera ready state
static CFAbsoluteTime gLastCameraReadyNotificationTime = 0;
static BOOL gCameraWantsVolumeButtonEvents = NO;
static NSUInteger gCameraReadyNotificationGeneration = 0;
static BOOL gCameraReadyNotificationPending = NO;

// Phone keypad state
static BOOL gPhonePendingKeypadTabSelection = NO;

#pragma mark - Camera Ready Notification

static void LATPostCameraReadyNotificationIfNeeded(void) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - gLastCameraReadyNotificationTime < LATCameraReadyNotificationThrottle) {
        return;
    }

    gLastCameraReadyNotificationTime = now;
    notify_post(LATCameraReadyNotification);
}

#pragma mark - Camera State

static BOOL LATCameraApplicationIsActive(void) {
    return UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
}

#pragma mark - Camera Ready Scheduling

static void LATCancelPendingCameraReadyNotification(void) {
    gCameraReadyNotificationGeneration++;
    gCameraReadyNotificationPending = NO;
}

static void LATScheduleCameraReadyNotificationAfterControlsUpdate(void) {
    BOOL active = LATCameraApplicationIsActive();
    if (!active || !gCameraWantsVolumeButtonEvents) {
        LATCancelPendingCameraReadyNotification();
        return;
    }

    gCameraReadyNotificationGeneration++;
    NSUInteger generation = gCameraReadyNotificationGeneration;
    gCameraReadyNotificationPending = YES;
    HBLogDebug(@"Scheduled delayed Camera ready notification active=%d wantsVolumeButtonEvents=%d", active,
               gCameraWantsVolumeButtonEvents);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATCameraReadyNotificationDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       if (generation != gCameraReadyNotificationGeneration) {
                           return;
                       }

                       gCameraReadyNotificationPending = NO;
                       if (!LATCameraApplicationIsActive() || !gCameraWantsVolumeButtonEvents) {
                           HBLogDebug(@"Canceled delayed Camera ready notification active=%d wantsVolumeButtonEvents=%d",
                                      LATCameraApplicationIsActive(), gCameraWantsVolumeButtonEvents);
                           return;
                       }

                       HBLogDebug(@"Posting delayed Camera ready notification active=%d wantsVolumeButtonEvents=%d",
                                  LATCameraApplicationIsActive(), gCameraWantsVolumeButtonEvents);
                       LATPostCameraReadyNotificationIfNeeded();
                   });
}

static void LATCameraApplicationWillResignActive(NSNotification *notification) {
    (void)notification;
    LATCancelPendingCameraReadyNotification();
}

#pragma mark - Camera Hooks

CHOptimizedMethod1(self, void, UIApplication, setWantsVolumeButtonEvents, BOOL, wantsVolumeButtonEvents) {
    CHSuper1(UIApplication, setWantsVolumeButtonEvents, wantsVolumeButtonEvents);
    gCameraWantsVolumeButtonEvents = wantsVolumeButtonEvents;
    HBLogDebug(@"Camera setWantsVolumeButtonEvents:%d active=%d", wantsVolumeButtonEvents,
               LATCameraApplicationIsActive());
    if (!wantsVolumeButtonEvents) {
        LATCancelPendingCameraReadyNotification();
    }
}

CHOptimizedMethod2(self, void, CAMViewfinderViewController, _updateEnabledControlsWithReason, NSString *, reason,
                   forceLog, BOOL, forceLog) {
    CHSuper2(CAMViewfinderViewController, _updateEnabledControlsWithReason, reason, forceLog, forceLog);
    BOOL active = LATCameraApplicationIsActive();
    HBLogDebug(@"Camera controls updated for reason=%@ active=%d wantsVolumeButtonEvents=%d pendingReady=%d",
               reason ?: @"", active, gCameraWantsVolumeButtonEvents, gCameraReadyNotificationPending);
    LATScheduleCameraReadyNotificationAfterControlsUpdate();
}

#pragma mark - Camera Hook Installation

static void LATInstallCameraHooks(void) {
    Class applicationClass = UIApplication.class;
    if (![applicationClass instancesRespondToSelector:@selector(setWantsVolumeButtonEvents:)]) {
        HBLogWarn(@"Skipping Camera ready hook because UIApplication does not expose setWantsVolumeButtonEvents:");
        return;
    }

    CHLoadClass_(&UIApplication$, applicationClass);
    CHHook1(UIApplication, setWantsVolumeButtonEvents);

    Class viewfinderClass = NSClassFromString(@"CAMViewfinderViewController");
    if (![viewfinderClass instancesRespondToSelector:@selector(_updateEnabledControlsWithReason:forceLog:)]) {
        HBLogWarn(@"Skipping Camera controls readiness hook because CAMViewfinderViewController does not expose _updateEnabledControlsWithReason:forceLog:");
    } else {
        CHLoadClass_(&CAMViewfinderViewController$, viewfinderClass);
        CHHook2(CAMViewfinderViewController, _updateEnabledControlsWithReason, forceLog);
    }

    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification
                                                    object:nil
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *notification) {
                                                    LATCameraApplicationWillResignActive(notification);
                                                }];
}

#pragma mark - Phone URL Matching

static BOOL LATStringContainsAnyToken(NSString *string, NSArray<NSString *> *tokens) {
    NSString *lowercaseString = string.lowercaseString;
    for (NSString *token in tokens) {
        if ([lowercaseString containsString:token]) {
            return YES;
        }
    }
    return NO;
}

static BOOL LATPhoneURLRequestsKeypad(NSURL *url) {
    return [url.absoluteString.lowercaseString isEqualToString:LATPhoneKeypadURLString];
}

#pragma mark - Phone View Controller Lookup

static UIViewController *LATPhoneKeypadViewControllerInTabBarController(UITabBarController *tabBarController) {
    if ([tabBarController respondsToSelector:@selector(keypadViewController)]) {
        UIViewController *keypadViewController = [(PhoneTabBarController *)tabBarController keypadViewController];
        if ([keypadViewController isKindOfClass:UIViewController.class]) {
            return keypadViewController;
        }
    }

    NSArray<NSString *> *tokens = @[ @"keypad", @"dialer" ];
    [tabBarController.viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger index,
                                                                   BOOL *stop) {
        NSString *className = NSStringFromClass(viewController.class);
        NSString *accessibilityIdentifier = viewController.tabBarItem.accessibilityIdentifier ?: @"";
        NSString *title = viewController.tabBarItem.title ?: viewController.title ?: @"";
        HBLogDebug(@"Phone tab[%lu] class=%@ title=%@ accessibilityIdentifier=%@", (unsigned long)index, className,
                   title, accessibilityIdentifier);
        if (LATStringContainsAnyToken(className, tokens) ||
            LATStringContainsAnyToken(accessibilityIdentifier, tokens) ||
            LATStringContainsAnyToken(title, tokens)) {
            *stop = YES;
        }
    }];

    for (UIViewController *viewController in tabBarController.viewControllers) {
        NSString *className = NSStringFromClass(viewController.class);
        NSString *accessibilityIdentifier = viewController.tabBarItem.accessibilityIdentifier ?: @"";
        NSString *title = viewController.tabBarItem.title ?: viewController.title ?: @"";
        if (LATStringContainsAnyToken(className, tokens) ||
            LATStringContainsAnyToken(accessibilityIdentifier, tokens) ||
            LATStringContainsAnyToken(title, tokens)) {
            return viewController;
        }
    }

    return nil;
}

static UITabBarController *LATPhoneFindTabBarControllerInViewController(UIViewController *viewController,
                                                                        NSMutableSet<NSValue *> *visitedViewControllers) {
    if (!viewController) {
        return nil;
    }

    NSValue *viewControllerKey = [NSValue valueWithNonretainedObject:viewController];
    if ([visitedViewControllers containsObject:viewControllerKey]) {
        return nil;
    }
    [visitedViewControllers addObject:viewControllerKey];

    if ([viewController isKindOfClass:UITabBarController.class]) {
        return (UITabBarController *)viewController;
    }

    UIViewController *baseViewController = nil;
    if ([viewController respondsToSelector:@selector(baseViewController)]) {
        baseViewController = [(MPRootViewController *)viewController baseViewController];
    }
    if ([baseViewController isKindOfClass:UIViewController.class]) {
        UITabBarController *tabBarController =
            LATPhoneFindTabBarControllerInViewController(baseViewController, visitedViewControllers);
        if (tabBarController) {
            HBLogDebug(@"Phone tab bar controller from %@ baseViewController: %@", viewController, tabBarController);
            return tabBarController;
        }
    }

    UIViewController *tabBarViewController = nil;
    if ([viewController respondsToSelector:@selector(tabBarViewController)]) {
        tabBarViewController = [viewController tabBarViewController];
    }
    if ([tabBarViewController isKindOfClass:UITabBarController.class]) {
        HBLogDebug(@"Phone tab bar controller from %@ tabBarViewController: %@", viewController, tabBarViewController);
        return (UITabBarController *)tabBarViewController;
    }

    if ([viewController.tabBarController isKindOfClass:UITabBarController.class]) {
        HBLogDebug(@"Phone tab bar controller from %@ tabBarController: %@", viewController,
                   viewController.tabBarController);
        return viewController.tabBarController;
    }

    for (UIViewController *childViewController in viewController.childViewControllers) {
        UITabBarController *tabBarController =
            LATPhoneFindTabBarControllerInViewController(childViewController, visitedViewControllers);
        if (tabBarController) {
            return tabBarController;
        }
    }

    if ([viewController isKindOfClass:UINavigationController.class]) {
        for (UIViewController *navigationViewController in ((UINavigationController *)viewController).viewControllers) {
            UITabBarController *tabBarController =
                LATPhoneFindTabBarControllerInViewController(navigationViewController, visitedViewControllers);
            if (tabBarController) {
                return tabBarController;
            }
        }
    }

    return LATPhoneFindTabBarControllerInViewController(viewController.presentedViewController, visitedViewControllers);
}

static UIViewController *LATPhoneRootViewControllerFromScenes(UIApplication *application) {
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow && [window.rootViewController isKindOfClass:UIViewController.class]) {
                return window.rootViewController;
            }
        }
    }

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if ([window.rootViewController isKindOfClass:UIViewController.class]) {
                return window.rootViewController;
            }
        }
    }

    return nil;
}

static UITabBarController *LATPhoneTabBarController(void) {
    UIApplication *application = UIApplication.sharedApplication;
    UIViewController *rootViewController = [application rootViewController];
    if (![rootViewController isKindOfClass:UIViewController.class]) {
        rootViewController = LATPhoneRootViewControllerFromScenes(application);
    }

    UITabBarController *tabBarController =
        LATPhoneFindTabBarControllerInViewController(rootViewController, [NSMutableSet set]);
    if (tabBarController) {
        return tabBarController;
    }

    HBLogWarn(@"Unable to locate Phone tab bar controller from root view controller %@", rootViewController);
    return nil;
}

#pragma mark - Phone Keypad Selection

static BOOL LATPhoneSelectKeypadTabInTabBarController(UITabBarController *tabBarController) {
    if (!tabBarController) {
        return NO;
    }

    UIViewController *keypadViewController = LATPhoneKeypadViewControllerInTabBarController(tabBarController);
    if (!keypadViewController) {
        return NO;
    }

    if ([tabBarController respondsToSelector:@selector(tabTypeForViewController:)] &&
        [tabBarController respondsToSelector:@selector(switchToTab:)]) {
        PhoneTabBarController *phoneTabBarController = (PhoneTabBarController *)tabBarController;
        NSInteger keypadTabType = [phoneTabBarController tabTypeForViewController:keypadViewController];
        [phoneTabBarController switchToTab:keypadTabType];
        HBLogDebug(@"Requested Phone keypad tab with tab type %ld", (long)keypadTabType);
        return YES;
    }

    tabBarController.selectedViewController = keypadViewController;
    HBLogDebug(@"Selected Phone keypad view controller %@", keypadViewController);
    return YES;
}

static BOOL LATPhoneApplyPendingKeypadTabSelectionIfPossible(void) {
    if (!gPhonePendingKeypadTabSelection) {
        return NO;
    }

    if (!LATPhoneSelectKeypadTabInTabBarController(LATPhoneTabBarController())) {
        return NO;
    }

    gPhonePendingKeypadTabSelection = NO;
    return YES;
}

static void LATPhoneRequestKeypadTabSelection(void) {
    gPhonePendingKeypadTabSelection = YES;
    if (!LATPhoneApplyPendingKeypadTabSelectionIfPossible()) {
        HBLogDebug(@"Deferred Phone keypad tab selection until the tab bar controller is ready");
    }
}

#pragma mark - Phone Application URL Hooks

CHOptimizedMethod1(self, BOOL, PhoneApplication, applicationOpenURL, NSURL *, url) {
    BOOL result = CHSuper1(PhoneApplication, applicationOpenURL, url);
    HBLogDebug(@"Phone applicationOpenURL: %@ result=%d", url.absoluteString ?: @"", result);
    if (LATPhoneURLRequestsKeypad(url)) {
        LATPhoneRequestKeypadTabSelection();
    }
    return result;
}

CHOptimizedMethod2(self, BOOL, PhoneApplication, applicationOpenURL, NSURL *, url, publicURLsOnly, BOOL, publicURLsOnly) {
    BOOL result = CHSuper2(PhoneApplication, applicationOpenURL, url, publicURLsOnly, publicURLsOnly);
    HBLogDebug(@"Phone applicationOpenURL:publicURLsOnly: %@ public=%d result=%d", url.absoluteString ?: @"",
               publicURLsOnly, result);
    if (LATPhoneURLRequestsKeypad(url)) {
        LATPhoneRequestKeypadTabSelection();
    }
    return result;
}

CHOptimizedMethod3(self, BOOL, PhoneApplication, application, UIApplication *, application, openURL, NSURL *, url,
                   options, NSDictionary *, options) {
    BOOL result = CHSuper3(PhoneApplication, application, application, openURL, url, options, options);
    HBLogDebug(@"Phone application:openURL:options: %@ options=%@ result=%d", url.absoluteString ?: @"", options ?: @{},
               result);
    if (LATPhoneURLRequestsKeypad(url)) {
        LATPhoneRequestKeypadTabSelection();
    }
    return result;
}

#pragma mark - Phone Tab Bar Hooks

CHOptimizedMethod0(self, id, PhoneTabBarController, init) {
    id result = CHSuper0(PhoneTabBarController, init);
    LATPhoneApplyPendingKeypadTabSelectionIfPossible();
    return result;
}

CHOptimizedMethod1(self, void, PhoneTabBarController, viewWillAppear, BOOL, animated) {
    LATPhoneApplyPendingKeypadTabSelectionIfPossible();
    CHSuper1(PhoneTabBarController, viewWillAppear, animated);
}

CHOptimizedMethod1(self, void, PhoneTabBarController, viewDidAppear, BOOL, animated) {
    CHSuper1(PhoneTabBarController, viewDidAppear, animated);
    if (gPhonePendingKeypadTabSelection && !LATPhoneApplyPendingKeypadTabSelectionIfPossible()) {
        HBLogWarn(@"Unable to open Phone keypad because the keypad tab is unavailable");
        gPhonePendingKeypadTabSelection = NO;
    }
}

#pragma mark - Phone Hook Installation

static void LATInstallPhoneHooks(void) {
    Class phoneApplicationClass = NSClassFromString(@"PhoneApplication");
    HBLogDebug(@"Phone keypad hook probe: PhoneApplication=%@ applicationOpenURL=%d applicationOpenURLPublic=%d applicationOpenURLOptions=%d",
               phoneApplicationClass,
               [phoneApplicationClass instancesRespondToSelector:@selector(applicationOpenURL:)],
               [phoneApplicationClass instancesRespondToSelector:@selector(applicationOpenURL:publicURLsOnly:)],
               [phoneApplicationClass instancesRespondToSelector:@selector(application:openURL:options:)]);
    if (!phoneApplicationClass) {
        HBLogWarn(@"Skipping Phone keypad hook because PhoneApplication is unavailable");
        return;
    }
    CHLoadClass_(&PhoneApplication$, phoneApplicationClass);
    if ([phoneApplicationClass instancesRespondToSelector:@selector(applicationOpenURL:)]) {
        CHHook1(PhoneApplication, applicationOpenURL);
    }
    if ([phoneApplicationClass instancesRespondToSelector:@selector(applicationOpenURL:publicURLsOnly:)]) {
        CHHook2(PhoneApplication, applicationOpenURL, publicURLsOnly);
    }
    if ([phoneApplicationClass instancesRespondToSelector:@selector(application:openURL:options:)]) {
        CHHook3(PhoneApplication, application, openURL, options);
    }

    Class phoneTabBarControllerClass = NSClassFromString(@"PhoneTabBarController");
    if (!phoneTabBarControllerClass) {
        HBLogWarn(@"Skipping Phone tab bar controller hooks because PhoneTabBarController is unavailable");
        return;
    }

    CHLoadClass_(&PhoneTabBarController$, phoneTabBarControllerClass);
    if ([phoneTabBarControllerClass instancesRespondToSelector:@selector(init)]) {
        CHHook0(PhoneTabBarController, init);
    }
    if ([phoneTabBarControllerClass instancesRespondToSelector:@selector(viewWillAppear:)]) {
        CHHook1(PhoneTabBarController, viewWillAppear);
    }
    if ([phoneTabBarControllerClass instancesRespondToSelector:@selector(viewDidAppear:)]) {
        CHHook1(PhoneTabBarController, viewDidAppear);
    }
}

#pragma mark - Constructor

__attribute__((constructor)) static void LATAppTweakInitialize(void) {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if ([bundleIdentifier isEqualToString:@"com.apple.camera"]) {
        LATInstallCameraHooks();
    } else if ([bundleIdentifier isEqualToString:@"com.apple.mobilephone"]) {
        LATInstallPhoneHooks();
    }
}
