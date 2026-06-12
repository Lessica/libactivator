//
//  ActivatorTweak.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#define CHUseSubstrate

#import "LAActivator+Private.h"
#import "LATBuiltInRegistry.h"
#import "LATRuntimeStateSource.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>

CHDeclareClass(SpringBoard);
CHDeclareClass(UIViewController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);
CHDeclareClass(SBVolumeControl);
CHDeclareClass(SBHIconManager);
CHDeclareClass(_UISystemGestureWindow);

static NSString *const LATRuntimeStateSourceCoverSheetTransition = @"cover-sheet-transition";
static NSString *const LATRuntimeStateSourceIconManagerRootFolder = @"icon-manager-root-folder";
static NSString *const LATRuntimeStateSourceMainSwitcher = @"main-switcher";

static LATBuiltInRegistry *gBuiltInRegistry = nil;

static Class gCoverSheetViewControllerClass = nil;
static Class gPosterSwitcherViewControllerClass = nil;
static Class gDashboardCameraPageViewControllerClass = nil;
static Class gInCallTransientOverlayViewControllerClass = nil;
static Class gLockScreenEmergencyCallViewControllerClass = nil;
static Class gIconControllerClass = nil;

static void LATNoteViewControllerVisibility(id viewController, BOOL visible) {
    if (gCoverSheetViewControllerClass && [viewController isKindOfClass:gCoverSheetViewControllerClass]) {
        gBuiltInRegistry.coverSheetViewControllerInstance = (CSCoverSheetViewController *)viewController;
    }

    if ((gCoverSheetViewControllerClass && [viewController isKindOfClass:gCoverSheetViewControllerClass]) ||
        (gPosterSwitcherViewControllerClass && [viewController isKindOfClass:gPosterSwitcherViewControllerClass]) ||
        (gDashboardCameraPageViewControllerClass &&
         [viewController isKindOfClass:gDashboardCameraPageViewControllerClass]) ||
        (gInCallTransientOverlayViewControllerClass &&
         [viewController isKindOfClass:gInCallTransientOverlayViewControllerClass]) ||
        (gLockScreenEmergencyCallViewControllerClass &&
         [viewController isKindOfClass:gLockScreenEmergencyCallViewControllerClass])) {
        [gBuiltInRegistry.runtimeStateSource noteLockScreenVisible:visible
                                                            source:NSStringFromClass([viewController class])];
    } else if (gIconControllerClass && [viewController isKindOfClass:gIconControllerClass]) {
        [gBuiltInRegistry.runtimeStateSource noteHomeScreenVisible:visible
                                                            source:NSStringFromClass([viewController class])];
    }
    [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
}

@interface SBMainSwitcherViewController : UIViewController
- (BOOL)isMainSwitcherVisible;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
- (BOOL)isAnySwitcherVisible;
@end

static void LATUpdateMainSwitcherVisibility(SBMainSwitcherViewController *switcher) {
    dispatch_block_t updateBlock = ^{
        if (![switcher respondsToSelector:@selector(isMainSwitcherVisible)]) {
            return;
        }
        [gBuiltInRegistry.runtimeStateSource noteSpringBoardInterfaceVisible:[switcher isMainSwitcherVisible]
                                                                      source:LATRuntimeStateSourceMainSwitcher];
        [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
    };
    if ([NSThread isMainThread]) {
        updateBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), updateBlock);
    }
}

static void LATUpdateMainSwitcherCoordinatorVisibility(SBMainSwitcherControllerCoordinator *coordinator) {
    dispatch_block_t updateBlock = ^{
        if (![coordinator respondsToSelector:@selector(isAnySwitcherVisible)]) {
            [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
            return;
        }
        [gBuiltInRegistry.runtimeStateSource noteSpringBoardInterfaceVisible:[coordinator isAnySwitcherVisible]
                                                                      source:LATRuntimeStateSourceMainSwitcher];
        [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
    };
    if ([NSThread isMainThread]) {
        updateBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), updateBlock);
    }
}

#pragma mark - UIViewController

CHOptimizedMethod1(self, void, UIViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillAppear, animated);
    LATNoteViewControllerVisibility(self, YES);
}

CHOptimizedMethod1(self, void, UIViewController, viewDidDisappear, BOOL, animated) {
    CHSuper1(UIViewController, viewDidDisappear, animated);
    LATNoteViewControllerVisibility(self, NO);
}

#pragma mark - SBCoverSheetPrimarySlidingViewController

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared, appeared);
    [gBuiltInRegistry.runtimeStateSource noteLockScreenVisible:YES source:LATRuntimeStateSourceCoverSheetTransition];
}

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, appeared);
    [gBuiltInRegistry.runtimeStateSource noteLockScreenVisible:NO source:LATRuntimeStateSourceCoverSheetTransition];
}

#pragma mark - SBMainSwitcherViewController

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    LATUpdateMainSwitcherVisibility(self);
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    LATUpdateMainSwitcherVisibility(self);
}

#pragma mark - SBMainSwitcherControllerCoordinator

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    LATUpdateMainSwitcherCoordinatorVisibility(self);
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    LATUpdateMainSwitcherCoordinatorVisibility(self);
}

#pragma mark - SBVolumeControl

CHOptimizedMethod4(self, id, SBVolumeControl, initWithHUDController, id, hudController, ringerControl,
                   SBRingerControl *, ringerControl, telephonyManager, id, telephonyManager, conferenceManager, id,
                   conferenceManager) {
    SBVolumeControl *instance =
        CHSuper4(SBVolumeControl, initWithHUDController, hudController, ringerControl, ringerControl, telephonyManager,
                 telephonyManager, conferenceManager, conferenceManager);
    gBuiltInRegistry.volumeControlInstance = instance;
    gBuiltInRegistry.ringerControlInstance = ringerControl;
    return instance;
}

#pragma mark - SBHIconManager

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewWillAppear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewWillAppear, controller);
    [gBuiltInRegistry.runtimeStateSource noteHomeScreenVisible:YES source:LATRuntimeStateSourceIconManagerRootFolder];
    [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewDidDisappear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewDidDisappear, controller);
    [gBuiltInRegistry.runtimeStateSource noteHomeScreenVisible:NO source:LATRuntimeStateSourceIconManagerRootFolder];
    [gBuiltInRegistry.runtimeStateSource refreshForegroundDisplayIdentifier];
}

#pragma mark - _UISystemGestureWindow

CHOptimizedMethod1(self, void, _UISystemGestureWindow, sendEvent, UIEvent *, event) {
    CHSuper1(_UISystemGestureWindow, sendEvent, event);
    [gBuiltInRegistry.runtimeStateSource noteSystemTouchEvent:event];
}

#pragma mark - SpringBoard

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    [gBuiltInRegistry startEventSources];
    [LASharedActivator startIPCServerIfNeeded];
}

#pragma mark - Hook Installation

static void LATLoadRuntimeStateClasses(void) {
    gCoverSheetViewControllerClass = NSClassFromString(@"CSCoverSheetViewController");
    gPosterSwitcherViewControllerClass = NSClassFromString(@"CSPosterSwitcherViewController");
    gDashboardCameraPageViewControllerClass = NSClassFromString(@"SBDashBoardCameraPageViewController");
    gInCallTransientOverlayViewControllerClass = NSClassFromString(@"SBInCallTransientOverlayViewController");
    gLockScreenEmergencyCallViewControllerClass = NSClassFromString(@"SBLockScreenEmergencyCallViewController");
    gIconControllerClass = NSClassFromString(@"SBIconController");
}

static void LATLoadSpringBoardClasses(void) {
    CHLoadClass(UIViewController);
    CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
    CHLoadClass_(&SBCoverSheetPrimarySlidingViewController$,
                 NSClassFromString(@"SBCoverSheetPrimarySlidingViewController"));
    CHLoadClass_(&SBMainSwitcherViewController$, NSClassFromString(@"SBMainSwitcherViewController"));
    CHLoadClass_(&SBMainSwitcherControllerCoordinator$, NSClassFromString(@"SBMainSwitcherControllerCoordinator"));
    CHLoadClass_(&SBVolumeControl$, NSClassFromString(@"SBVolumeControl"));
    CHLoadClass_(&SBHIconManager$, NSClassFromString(@"SBHIconManager"));
    CHLoadClass_(&_UISystemGestureWindow$, NSClassFromString(@"_UISystemGestureWindow"));
}

static void LATInstallHooks(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        LATLoadRuntimeStateClasses();
        LATLoadSpringBoardClasses();

        CHHook1(UIViewController, viewWillAppear);
        CHHook1(UIViewController, viewDidDisappear);
        CHHook1(SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared);
        CHHook1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared);
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, transitionDidEndWithTransitionContext);
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidEndWithTransitionContext);
        CHHook4(SBVolumeControl, initWithHUDController, ringerControl, telephonyManager, conferenceManager);
        if (@available(iOS 17, *)) {
            CHHook1(SBHIconManager, rootFolderControllerViewWillAppear);
            CHHook1(SBHIconManager, rootFolderControllerViewDidDisappear);
        }
        CHHook1(_UISystemGestureWindow, sendEvent);
        CHHook1(SpringBoard, applicationDidFinishLaunching);
    });
}

__attribute__((constructor)) static void LATweakInitialize(void) {
    gBuiltInRegistry = [[LATBuiltInRegistry alloc] initWithActivator:[LAActivator sharedInstance]];
    LATInstallHooks();
}
