//
//  ActivatorTweak.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorPrivate.h"

#import <objc/runtime.h>
#import <substrate.h>
#import <notify.h>
#import <UIKit/UIKit.h>

static void (*LATOrigUIViewControllerViewWillAppear)(id, SEL, BOOL);
static void (*LATOrigUIViewControllerViewDidDisappear)(id, SEL, BOOL);
static void (*LATOrigSBBacklightControllerTurnOnScreenFully)(id, SEL, long long);
static void (*LATOrigSBBacklightControllerNotifyDidAnimate)(id, SEL, float, long long);
static void (*LATOrigSBCoverSheetPrimarySlidingViewControllerEndTransition)(id, SEL, BOOL);
static void (*LATOrigSBHIconManagerRootFolderWillAppear)(id, SEL, id);
static void (*LATOrigSBHIconManagerRootFolderDidDisappear)(id, SEL, id);
static void (*LATOrigUISystemGestureWindowSendEvent)(id, SEL, UIEvent *);
static void (*LATOrigSpringBoardApplicationDidFinishLaunching)(id, SEL, id);

static BOOL LATHookInstanceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls || !class_getInstanceMethod(cls, selector)) {
        return NO;
    }
    MSHookMessageEx(cls, selector, replacement, original);
    return YES;
}

static void LATNoteRuntimeStateMayHaveChanged(void) {
    [[LAActivator sharedInstance] la_noteRuntimeStateMayHaveChanged];
}

static void LATNoteViewControllerVisibility(id viewController, BOOL visible) {
    Class coverSheetClass = NSClassFromString(@"CSCoverSheetViewController");
    Class dashboardCameraClass = NSClassFromString(@"SBDashBoardCameraPageViewController");
    Class emergencyCallClass = NSClassFromString(@"SBLockScreenEmergencyCallViewController");
    Class iconControllerClass = NSClassFromString(@"SBIconController");

    if ((coverSheetClass && [viewController isKindOfClass:coverSheetClass]) ||
        (dashboardCameraClass && [viewController isKindOfClass:dashboardCameraClass]) ||
        (emergencyCallClass && [viewController isKindOfClass:emergencyCallClass])) {
        [[LAActivator sharedInstance] la_noteLockScreenVisible:visible];
    } else if (iconControllerClass && [viewController isKindOfClass:iconControllerClass]) {
        [[LAActivator sharedInstance] la_noteHomeScreenVisible:visible];
    }
}

static void LATUIViewControllerViewWillAppear(id self, SEL _cmd, BOOL animated) {
    LATOrigUIViewControllerViewWillAppear(self, _cmd, animated);
    LATNoteViewControllerVisibility(self, YES);
}

static void LATUIViewControllerViewDidDisappear(id self, SEL _cmd, BOOL animated) {
    LATOrigUIViewControllerViewDidDisappear(self, _cmd, animated);
    LATNoteViewControllerVisibility(self, NO);
}

static void LATSBBacklightControllerTurnOnScreenFully(id self, SEL _cmd, long long source) {
    LATOrigSBBacklightControllerTurnOnScreenFully(self, _cmd, source);
    [[LAActivator sharedInstance] la_noteScreenBlanked:NO];
    [[LAActivator sharedInstance] la_noteLockScreenVisible:YES];
}

static void LATSBBacklightControllerNotifyDidAnimate(id self, SEL _cmd, float factor, long long source) {
    LATOrigSBBacklightControllerNotifyDidAnimate(self, _cmd, factor, source);
    [[LAActivator sharedInstance] la_noteScreenBlanked:factor <= 1e-3];
}

static void LATSBCoverSheetPrimarySlidingViewControllerEndTransition(id self, SEL _cmd, BOOL appeared) {
    LATOrigSBCoverSheetPrimarySlidingViewControllerEndTransition(self, _cmd, appeared);
    [[LAActivator sharedInstance] la_noteLockScreenVisible:appeared];
}

static void LATSBHIconManagerRootFolderWillAppear(id self, SEL _cmd, id controller) {
    LATOrigSBHIconManagerRootFolderWillAppear(self, _cmd, controller);
    [[LAActivator sharedInstance] la_noteHomeScreenVisible:YES];
}

static void LATSBHIconManagerRootFolderDidDisappear(id self, SEL _cmd, id controller) {
    LATOrigSBHIconManagerRootFolderDidDisappear(self, _cmd, controller);
    [[LAActivator sharedInstance] la_noteHomeScreenVisible:NO];
}

static void LATUISystemGestureWindowSendEvent(id self, SEL _cmd, UIEvent *event) {
    LATOrigUISystemGestureWindowSendEvent(self, _cmd, event);
    [[LAActivator sharedInstance] la_noteSystemTouchEvent:event];
}

static void LATSpringBoardApplicationDidFinishLaunching(id self, SEL _cmd, id application) {
    LATOrigSpringBoardApplicationDidFinishLaunching(self, _cmd, application);
    LATNoteRuntimeStateMayHaveChanged();
}

static void LATRegisterDarwinNotifications(void) {
    static int lockStateToken = 0;
    static int blankedScreenToken = 0;
    notify_register_dispatch("com.apple.springboard.lockstate", &lockStateToken, dispatch_get_main_queue(),
                             ^(int token) {
                               LATNoteRuntimeStateMayHaveChanged();
                             });
    notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &blankedScreenToken, dispatch_get_main_queue(),
                             ^(int token) {
                               uint64_t state = 0;
                               notify_get_state(token, &state);
                               [[LAActivator sharedInstance] la_noteScreenBlanked:state != 0];
                             });
}

static void LATInstallHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      LATHookInstanceMethod(UIViewController.class, @selector(viewWillAppear:), (IMP)LATUIViewControllerViewWillAppear,
                            (IMP *)&LATOrigUIViewControllerViewWillAppear);
      LATHookInstanceMethod(UIViewController.class, @selector(viewDidDisappear:),
                            (IMP)LATUIViewControllerViewDidDisappear,
                            (IMP *)&LATOrigUIViewControllerViewDidDisappear);
      LATHookInstanceMethod(NSClassFromString(@"SBBacklightController"),
                            @selector(turnOnScreenFullyWithBacklightSource:),
                            (IMP)LATSBBacklightControllerTurnOnScreenFully,
                            (IMP *)&LATOrigSBBacklightControllerTurnOnScreenFully);
      LATHookInstanceMethod(NSClassFromString(@"SBBacklightController"),
                            @selector(_notifyObserversDidAnimateToFactor:source:),
                            (IMP)LATSBBacklightControllerNotifyDidAnimate,
                            (IMP *)&LATOrigSBBacklightControllerNotifyDidAnimate);
      LATHookInstanceMethod(NSClassFromString(@"SBCoverSheetPrimarySlidingViewController"),
                            @selector(_endTransitionToAppeared:),
                            (IMP)LATSBCoverSheetPrimarySlidingViewControllerEndTransition,
                            (IMP *)&LATOrigSBCoverSheetPrimarySlidingViewControllerEndTransition);
      LATHookInstanceMethod(NSClassFromString(@"SBHIconManager"), @selector(rootFolderControllerViewWillAppear:),
                            (IMP)LATSBHIconManagerRootFolderWillAppear,
                            (IMP *)&LATOrigSBHIconManagerRootFolderWillAppear);
      LATHookInstanceMethod(NSClassFromString(@"SBHIconManager"), @selector(rootFolderControllerViewDidDisappear:),
                            (IMP)LATSBHIconManagerRootFolderDidDisappear,
                            (IMP *)&LATOrigSBHIconManagerRootFolderDidDisappear);
      LATHookInstanceMethod(NSClassFromString(@"_UISystemGestureWindow"), @selector(sendEvent:),
                            (IMP)LATUISystemGestureWindowSendEvent,
                            (IMP *)&LATOrigUISystemGestureWindowSendEvent);
      LATHookInstanceMethod(NSClassFromString(@"SpringBoard"), @selector(applicationDidFinishLaunching:),
                            (IMP)LATSpringBoardApplicationDidFinishLaunching,
                            (IMP *)&LATOrigSpringBoardApplicationDidFinishLaunching);
      LATRegisterDarwinNotifications();
    });
}

__attribute__((constructor)) static void LATweakInitialize(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    [activator startIPCServerIfNeeded];
    LATInstallHooks();
}
