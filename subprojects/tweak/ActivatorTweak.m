//
//  ActivatorTweak.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#define CHUseSubstrate

#import "LAActivatorPrivate.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <notify.h>

CHDeclareClass(SpringBoard);
CHDeclareClass(UIViewController);
CHDeclareClass(SBBacklightController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBHIconManager);
CHDeclareClass(_UISystemGestureWindow);

static NSString *const LATRuntimeStateSourceCoverSheetTransition = @"cover-sheet-transition";
static NSString *const LATRuntimeStateSourceIconManagerRootFolder = @"icon-manager-root-folder";
static LAActivator *LATActivator;
static Class LATCoverSheetViewControllerClass;
static Class LATPosterSwitcherViewControllerClass;
static Class LATDashboardCameraPageViewControllerClass;
static Class LATInCallTransientOverlayViewControllerClass;
static Class LATLockScreenEmergencyCallViewControllerClass;
static Class LATIconControllerClass;

static void LATNoteViewControllerVisibility(id viewController, BOOL visible) {
    if ((LATCoverSheetViewControllerClass && [viewController isKindOfClass:LATCoverSheetViewControllerClass]) ||
        (LATPosterSwitcherViewControllerClass && [viewController isKindOfClass:LATPosterSwitcherViewControllerClass]) ||
        (LATDashboardCameraPageViewControllerClass &&
         [viewController isKindOfClass:LATDashboardCameraPageViewControllerClass]) ||
        (LATInCallTransientOverlayViewControllerClass &&
         [viewController isKindOfClass:LATInCallTransientOverlayViewControllerClass]) ||
        (LATLockScreenEmergencyCallViewControllerClass &&
         [viewController isKindOfClass:LATLockScreenEmergencyCallViewControllerClass])) {
        [LATActivator la_noteLockScreenVisible:visible source:NSStringFromClass([viewController class])];
    } else if (LATIconControllerClass && [viewController isKindOfClass:LATIconControllerClass]) {
        [LATActivator la_noteHomeScreenVisible:visible source:NSStringFromClass([viewController class])];
    }
}

#pragma mark - UIViewController

CHOptimizedMethod1(self, void, UIViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillAppear, animated);
    LATNoteViewControllerVisibility(self, YES);
}

CHOptimizedMethod1(self, void, UIViewController, viewWillDisappear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillDisappear, animated);
    LATNoteViewControllerVisibility(self, NO);
}

CHOptimizedMethod1(self, void, UIViewController, viewDidDisappear, BOOL, animated) {
    CHSuper1(UIViewController, viewDidDisappear, animated);
    LATNoteViewControllerVisibility(self, NO);
}

#pragma mark - SBBacklightController

CHOptimizedMethod1(self, void, SBBacklightController, turnOnScreenFullyWithBacklightSource, long long, source) {
    CHSuper1(SBBacklightController, turnOnScreenFullyWithBacklightSource, source);
    [LATActivator la_noteScreenBlanked:NO];
    [LATActivator la_noteRuntimeStateMayHaveChanged];
}

CHOptimizedMethod2(self, void, SBBacklightController, _notifyObserversDidAnimateToFactor, float, factor, source,
                   long long, backlightSource) {
    CHSuper2(SBBacklightController, _notifyObserversDidAnimateToFactor, factor, source, backlightSource);
    [LATActivator la_noteScreenBlanked:factor <= 1e-3];
}

#pragma mark - SBCoverSheetPrimarySlidingViewController

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared, appeared);
    [LATActivator la_noteLockScreenVisible:YES source:LATRuntimeStateSourceCoverSheetTransition];
}

CHOptimizedMethod1(self, void, SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, BOOL, appeared) {
    CHSuper1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared, appeared);
    [LATActivator la_noteLockScreenVisible:NO source:LATRuntimeStateSourceCoverSheetTransition];
}

#pragma mark - SBHIconManager

CHOptimizedMethod0(self, void, SBHIconManager, rootFolderControllerViewWillAppear) {
    CHSuper0(SBHIconManager, rootFolderControllerViewWillAppear);
    [LATActivator la_noteHomeScreenVisible:YES source:LATRuntimeStateSourceIconManagerRootFolder];
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewWillAppear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewWillAppear, controller);
    [LATActivator la_noteHomeScreenVisible:YES source:LATRuntimeStateSourceIconManagerRootFolder];
}

CHOptimizedMethod0(self, void, SBHIconManager, rootFolderControllerViewDidDisappear) {
    CHSuper0(SBHIconManager, rootFolderControllerViewDidDisappear);
    [LATActivator la_noteHomeScreenVisible:NO source:LATRuntimeStateSourceIconManagerRootFolder];
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewDidDisappear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewDidDisappear, controller);
    [LATActivator la_noteHomeScreenVisible:NO source:LATRuntimeStateSourceIconManagerRootFolder];
}

#pragma mark - _UISystemGestureWindow

CHOptimizedMethod1(self, void, _UISystemGestureWindow, sendEvent, UIEvent *, event) {
    CHSuper1(_UISystemGestureWindow, sendEvent, event);
    [LATActivator la_noteSystemTouchEvent:event];
}

#pragma mark - SpringBoard

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    [LATActivator la_noteRuntimeStateMayHaveChanged];
}

#pragma mark - Darwin Notifications

static void LATRegisterDarwinNotifications(void) {
    static int lockStateToken = 0;
    static int blankedScreenToken = 0;
    notify_register_dispatch("com.apple.springboard.lockstate", &lockStateToken, dispatch_get_main_queue(),
                             ^(int token) {
                                 [LATActivator la_noteRuntimeStateMayHaveChanged];
                             });
    notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &blankedScreenToken, dispatch_get_main_queue(),
                             ^(int token) {
                                 uint64_t state = 0;
                                 notify_get_state(token, &state);
                                 [LATActivator la_noteScreenBlanked:state != 0];
                             });
}

#pragma mark - Hook Installation

static void LATLoadRuntimeStateClasses(void) {
    LATCoverSheetViewControllerClass = NSClassFromString(@"CSCoverSheetViewController");
    LATPosterSwitcherViewControllerClass = NSClassFromString(@"CSPosterSwitcherViewController");
    LATDashboardCameraPageViewControllerClass = NSClassFromString(@"SBDashBoardCameraPageViewController");
    LATInCallTransientOverlayViewControllerClass = NSClassFromString(@"SBInCallTransientOverlayViewController");
    LATLockScreenEmergencyCallViewControllerClass = NSClassFromString(@"SBLockScreenEmergencyCallViewController");
    LATIconControllerClass = NSClassFromString(@"SBIconController");
}

static void LATLoadSpringBoardClasses(void) {
    CHLoadClass(UIViewController);
    CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
    CHLoadClass_(&SBBacklightController$, NSClassFromString(@"SBBacklightController"));
    CHLoadClass_(&SBCoverSheetPrimarySlidingViewController$,
                 NSClassFromString(@"SBCoverSheetPrimarySlidingViewController"));
    CHLoadClass_(&SBHIconManager$, NSClassFromString(@"SBHIconManager"));
    CHLoadClass_(&_UISystemGestureWindow$, NSClassFromString(@"_UISystemGestureWindow"));
}

static void LATInstallHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LATLoadRuntimeStateClasses();
        LATLoadSpringBoardClasses();

        CHHook1(UIViewController, viewWillAppear);
        CHHook1(UIViewController, viewWillDisappear);
        CHHook1(UIViewController, viewDidDisappear);
        CHHook1(SBBacklightController, turnOnScreenFullyWithBacklightSource);
        CHHook2(SBBacklightController, _notifyObserversDidAnimateToFactor, source);
        CHHook1(SBCoverSheetPrimarySlidingViewController, _beginTransitionFromAppeared);
        CHHook1(SBCoverSheetPrimarySlidingViewController, _endTransitionToAppeared);
        CHHook0(SBHIconManager, rootFolderControllerViewWillAppear);
        CHHook1(SBHIconManager, rootFolderControllerViewWillAppear);
        CHHook0(SBHIconManager, rootFolderControllerViewDidDisappear);
        CHHook1(SBHIconManager, rootFolderControllerViewDidDisappear);
        CHHook1(_UISystemGestureWindow, sendEvent);
        CHHook1(SpringBoard, applicationDidFinishLaunching);

        LATRegisterDarwinNotifications();
    });
}

__attribute__((constructor)) static void LATweakInitialize(void) {
    LATActivator = [LAActivator sharedInstance];
    [LATActivator startIPCServerIfNeeded];
    LATInstallHooks();
}
