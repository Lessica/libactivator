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
#import "LATEventSource.h"
#import "LATEventSourceIngress.h"
#import "LATEventSourceRegistry.h"
#import "LATRuntimeStateSource.h"
#import "system/LATSystemCenterController.h"
#if LIBACTIVATOR_TEST_SUPPORT
#import "LATweakTestSupport.h"
#endif

#import <CaptainHook/CaptainHook.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>

CHDeclareClass(SpringBoard);
CHDeclareClass(UIApplication);
CHDeclareClass(SBApplicationController);
CHDeclareClass(CCUIModuleCollectionViewController);
CHDeclareClass(UIViewController);
CHDeclareClass(SBCoverSheetPrimarySlidingViewController);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);
CHDeclareClass(SBVolumeControl);
CHDeclareClass(SBHIconManager);
CHDeclareClass(SBIconScrollView);
CHDeclareClass(SBWiFiManager);
CHDeclareClass(_UISystemGestureWindow);
CHDeclareClass(__UISystemGestureManager);
CHDeclareClass(UIStatusBar_Modern);

static NSString *const LATRuntimeStateSourceCoverSheetTransition = @"cover-sheet-transition";
static NSString *const LATRuntimeStateSourceIconManagerRootFolder = @"icon-manager-root-folder";
static NSString *const LATRuntimeStateSourceMainSwitcher = @"main-switcher";

typedef NS_ENUM(unsigned char, LATSystemGestureDispatchMode) {
    LATSystemGestureDispatchModeIgnore = 1,
    LATSystemGestureDispatchModeContinueSending = 2,
};

static LATBuiltInRegistry *gBuiltInRegistry = nil;
static NSArray<id<LATEventSourceHIDIngress>> *gHIDEventSources = nil;
static NSArray<id<LATEventSourceIconScrollViewIngress>> *gIconScrollViewEventSources = nil;
static NSArray<id<LATEventSourceMotionIngress>> *gMotionEventSources = nil;
static NSArray<id<LATEventSourceNetworkStateIngress>> *gNetworkStateEventSources = nil;
static NSArray<id<LATEventSourceStatusBarTouchIngress>> *gStatusBarTouchEventSources = nil;
static NSArray<id<LATEventSourceSystemGestureWindowIngress>> *gSystemGestureWindowEventSources = nil;

static Class gApplicationControllerClass = nil;
static Class gCoverSheetViewControllerClass = nil;
static Class gPosterSwitcherViewControllerClass = nil;
static Class gDashboardCameraPageViewControllerClass = nil;
static Class gInCallTransientOverlayViewControllerClass = nil;
static Class gLockScreenEmergencyCallViewControllerClass = nil;
static Class gIconControllerClass = nil;
static Class gIconScrollViewClass = nil;

@interface CCUIModuleCollectionViewController : UIViewController
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
@end

@interface SBApplicationController : NSObject
- (void)applicationsAdded:(id)added;
- (void)applicationsDemoted:(id)demoted;
- (void)applicationsRemoved:(id)removed;
- (void)applicationsReplaced:(id)replaced;
- (void)applicationsUpdated:(id)updated;
@end

static void LATNoteHIDEvent(IOHIDEventRef event) {
    for (id<LATEventSourceHIDIngress> eventSource in gHIDEventSources) {
        [eventSource noteHIDEvent:event];
    }
}

static void LATNoteApplicationCatalogMayHaveChanged(NSString *reason) {
    [gBuiltInRegistry noteApplicationCatalogMayHaveChangedWithReason:reason];
}

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

@interface SBIconScrollView : UIScrollView
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

#pragma mark - CCUIModuleCollectionViewController

CHOptimizedMethod0(self, void, CCUIModuleCollectionViewController, viewDidLoad) {
    CHSuper0(CCUIModuleCollectionViewController, viewDidLoad);
    [LATSystemCenterController noteModuleCollectionViewControllerDidLoad:self];
}

CHOptimizedMethod1(self, void, CCUIModuleCollectionViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(CCUIModuleCollectionViewController, viewWillAppear, animated);
    [LATSystemCenterController noteModuleCollectionViewControllerWillAppear:self];
}

#pragma mark - SBApplicationController

CHOptimizedMethod1(self, void, SBApplicationController, applicationsAdded, id, added) {
    CHSuper1(SBApplicationController, applicationsAdded, added);
    LATNoteApplicationCatalogMayHaveChanged(@"applications-added");
}

CHOptimizedMethod1(self, void, SBApplicationController, applicationsDemoted, id, demoted) {
    CHSuper1(SBApplicationController, applicationsDemoted, demoted);
    LATNoteApplicationCatalogMayHaveChanged(@"applications-demoted");
}

CHOptimizedMethod1(self, void, SBApplicationController, applicationsRemoved, id, removed) {
    CHSuper1(SBApplicationController, applicationsRemoved, removed);
    LATNoteApplicationCatalogMayHaveChanged(@"applications-removed");
}

CHOptimizedMethod1(self, void, SBApplicationController, applicationsReplaced, id, replaced) {
    CHSuper1(SBApplicationController, applicationsReplaced, replaced);
    LATNoteApplicationCatalogMayHaveChanged(@"applications-replaced");
}

CHOptimizedMethod1(self, void, SBApplicationController, applicationsUpdated, id, updated) {
    CHSuper1(SBApplicationController, applicationsUpdated, updated);
    LATNoteApplicationCatalogMayHaveChanged(@"applications-updated");
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

#pragma mark - SBIconScrollView

CHOptimizedMethod1(self, id, SBIconScrollView, initWithFrame, CGRect, frame) {
    SBIconScrollView *scrollView = CHSuper1(SBIconScrollView, initWithFrame, frame);
    for (id<LATEventSourceIconScrollViewIngress> eventSource in gIconScrollViewEventSources) {
        [eventSource noteIconScrollViewDidInitialize:(UIScrollView *)scrollView];
    }
    return scrollView;
}

#pragma mark - SBWiFiManager

CHOptimizedMethod0(self, void, SBWiFiManager, _updateCurrentNetwork) {
    CHSuper0(SBWiFiManager, _updateCurrentNetwork);
    for (id<LATEventSourceNetworkStateIngress> eventSource in gNetworkStateEventSources) {
        [eventSource noteNetworkStateMayHaveChangedWithReason:@"wifi-update-current-network"];
    }
}

CHOptimizedMethod0(self, void, SBWiFiManager, _linkDidChange) {
    CHSuper0(SBWiFiManager, _linkDidChange);
    for (id<LATEventSourceNetworkStateIngress> eventSource in gNetworkStateEventSources) {
        [eventSource noteNetworkStateMayHaveChangedWithReason:@"wifi-link-did-change"];
    }
}

#pragma mark - _UISystemGestureWindow

CHOptimizedMethod1(self, void, _UISystemGestureWindow, sendEvent, UIEvent *, event) {
    for (id<LATEventSourceSystemGestureWindowIngress> eventSource in gSystemGestureWindowEventSources) {
        [eventSource noteSystemGestureWindow:(UIWindow *)self event:event];
    }
    CHSuper1(_UISystemGestureWindow, sendEvent, event);
    [gBuiltInRegistry.runtimeStateSource noteSystemTouchEvent:event];
}

#pragma mark - __UISystemGestureManager

CHOptimizedMethod0(self, unsigned char, __UISystemGestureManager, _dispatchModeForExternalGestureCompletion) {
    unsigned char dispatchMode = CHSuper0(__UISystemGestureManager, _dispatchModeForExternalGestureCompletion);
    LATEventSourceRegistry *eventSourceRegistry = gBuiltInRegistry.eventSourceRegistry;
    BOOL shouldKeepSending = NO;
    for (id<LATEventSourceSystemGestureWindowIngress> eventSource in gSystemGestureWindowEventSources) {
        if ([eventSourceRegistry isInterestedInEventSource:(id<LATEventSource>)eventSource]) {
            shouldKeepSending = YES;
            break;
        }
    }
    if (dispatchMode == LATSystemGestureDispatchModeIgnore && shouldKeepSending) {
        return LATSystemGestureDispatchModeContinueSending;
    }
    return dispatchMode;
}

#pragma mark - UIStatusBar_Modern

CHOptimizedMethod2(self, void, UIStatusBar_Modern, touchesBegan, NSSet *, touches, withEvent, UIEvent *, event) {
    for (id<LATEventSourceStatusBarTouchIngress> eventSource in gStatusBarTouchEventSources) {
        [eventSource noteStatusBarView:(UIView *)self touchesBegan:touches withEvent:event];
    }
    CHSuper2(UIStatusBar_Modern, touchesBegan, touches, withEvent, event);
}

CHOptimizedMethod2(self, void, UIStatusBar_Modern, touchesMoved, NSSet *, touches, withEvent, UIEvent *, event) {
    for (id<LATEventSourceStatusBarTouchIngress> eventSource in gStatusBarTouchEventSources) {
        [eventSource noteStatusBarView:(UIView *)self touchesMoved:touches withEvent:event];
    }
    CHSuper2(UIStatusBar_Modern, touchesMoved, touches, withEvent, event);
}

CHOptimizedMethod2(self, void, UIStatusBar_Modern, touchesEnded, NSSet *, touches, withEvent, UIEvent *, event) {
    for (id<LATEventSourceStatusBarTouchIngress> eventSource in gStatusBarTouchEventSources) {
        [eventSource noteStatusBarView:(UIView *)self touchesEnded:touches withEvent:event];
    }
    CHSuper2(UIStatusBar_Modern, touchesEnded, touches, withEvent, event);
}

CHOptimizedMethod2(self, void, UIStatusBar_Modern, touchesCancelled, NSSet *, touches, withEvent, UIEvent *, event) {
    for (id<LATEventSourceStatusBarTouchIngress> eventSource in gStatusBarTouchEventSources) {
        [eventSource noteStatusBarView:(UIView *)self touchesCancelled:touches withEvent:event];
    }
    CHSuper2(UIStatusBar_Modern, touchesCancelled, touches, withEvent, event);
}

#pragma mark - UIApplication

CHOptimizedMethod2(self, void, UIApplication, motionEnded, UIEventSubtype, motion, withEvent, UIEvent *, event) {
    for (id<LATEventSourceMotionIngress> eventSource in gMotionEventSources) {
        [eventSource noteMotionEnded:motion];
    }
    CHSuper2(UIApplication, motionEnded, motion, withEvent, event);
}

#pragma mark - SpringBoard

CHOptimizedMethod2(self, BOOL, SpringBoard, __handleHIDEvent, IOHIDEventRef, event, withUIEvent, id, uiEvent) {
    LATNoteHIDEvent(event);
    return CHSuper2(SpringBoard, __handleHIDEvent, event, withUIEvent, uiEvent);
}

CHOptimizedMethod1(self, BOOL, SpringBoard, __handleHIDEvent, IOHIDEventRef, event) {
    LATNoteHIDEvent(event);
    return CHSuper1(SpringBoard, __handleHIDEvent, event);
}

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    [gBuiltInRegistry startEventSources];
    [LASharedActivator startIPCServerIfNeeded];
}

#pragma mark - Hook Installation

static void LATLoadRuntimeStateClasses(void) {
    gApplicationControllerClass = NSClassFromString(@"SBApplicationController");
    gCoverSheetViewControllerClass = NSClassFromString(@"CSCoverSheetViewController");
    gPosterSwitcherViewControllerClass = NSClassFromString(@"CSPosterSwitcherViewController");
    gDashboardCameraPageViewControllerClass = NSClassFromString(@"SBDashBoardCameraPageViewController");
    gInCallTransientOverlayViewControllerClass = NSClassFromString(@"SBInCallTransientOverlayViewController");
    gLockScreenEmergencyCallViewControllerClass = NSClassFromString(@"SBLockScreenEmergencyCallViewController");
    gIconControllerClass = NSClassFromString(@"SBIconController");
    gIconScrollViewClass = NSClassFromString(@"SBIconScrollView");
}

static void LATLoadSpringBoardClasses(void) {
    CHLoadClass(UIViewController);
    CHLoadClass(UIApplication);
    CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
    if (gApplicationControllerClass) {
        CHLoadClass_(&SBApplicationController$, gApplicationControllerClass);
    }
    CHLoadClass_(&CCUIModuleCollectionViewController$, NSClassFromString(@"CCUIModuleCollectionViewController"));
    CHLoadClass_(&SBCoverSheetPrimarySlidingViewController$,
                 NSClassFromString(@"SBCoverSheetPrimarySlidingViewController"));
    CHLoadClass_(&SBMainSwitcherViewController$, NSClassFromString(@"SBMainSwitcherViewController"));
    CHLoadClass_(&SBMainSwitcherControllerCoordinator$, NSClassFromString(@"SBMainSwitcherControllerCoordinator"));
    CHLoadClass_(&SBVolumeControl$, NSClassFromString(@"SBVolumeControl"));
    CHLoadClass_(&SBHIconManager$, NSClassFromString(@"SBHIconManager"));
    if (gIconScrollViewClass) {
        CHLoadClass_(&SBIconScrollView$, gIconScrollViewClass);
    }
    CHLoadClass_(&SBWiFiManager$, NSClassFromString(@"SBWiFiManager"));
    CHLoadClass_(&_UISystemGestureWindow$, NSClassFromString(@"_UISystemGestureWindow"));
    CHLoadClass_(&__UISystemGestureManager$, NSClassFromString(@"__UISystemGestureManager"));
    CHLoadClass_(&UIStatusBar_Modern$, NSClassFromString(@"UIStatusBar_Modern"));
}

static void LATInstallApplicationControllerHooks(void) {
    if (!gApplicationControllerClass) {
        HBLogWarn(@"Skipping SBApplicationController application catalog hooks because the class is unavailable");
        return;
    }

    if ([gApplicationControllerClass instancesRespondToSelector:@selector(applicationsAdded:)]) {
        CHHook1(SBApplicationController, applicationsAdded);
    } else {
        HBLogWarn(@"Skipping SBApplicationController applicationsAdded: hook because the method is unavailable");
    }
    if ([gApplicationControllerClass instancesRespondToSelector:@selector(applicationsDemoted:)]) {
        CHHook1(SBApplicationController, applicationsDemoted);
    } else {
        HBLogWarn(@"Skipping SBApplicationController applicationsDemoted: hook because the method is unavailable");
    }
    if ([gApplicationControllerClass instancesRespondToSelector:@selector(applicationsRemoved:)]) {
        CHHook1(SBApplicationController, applicationsRemoved);
    } else {
        HBLogWarn(@"Skipping SBApplicationController applicationsRemoved: hook because the method is unavailable");
    }
    if ([gApplicationControllerClass instancesRespondToSelector:@selector(applicationsReplaced:)]) {
        CHHook1(SBApplicationController, applicationsReplaced);
    } else {
        HBLogWarn(@"Skipping SBApplicationController applicationsReplaced: hook because the method is unavailable");
    }
    if ([gApplicationControllerClass instancesRespondToSelector:@selector(applicationsUpdated:)]) {
        CHHook1(SBApplicationController, applicationsUpdated);
    } else {
        HBLogWarn(@"Skipping SBApplicationController applicationsUpdated: hook because the method is unavailable");
    }
}

static void LATInstallHooks(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        LATLoadRuntimeStateClasses();
        LATLoadSpringBoardClasses();

        CHHook1(UIViewController, viewWillAppear);
        CHHook1(UIViewController, viewDidDisappear);
        LATInstallApplicationControllerHooks();
        Class moduleCollectionViewControllerClass = NSClassFromString(@"CCUIModuleCollectionViewController");
        if ([moduleCollectionViewControllerClass instancesRespondToSelector:@selector(viewDidLoad)] &&
            [moduleCollectionViewControllerClass instancesRespondToSelector:@selector(viewWillAppear:)]) {
            CHHook0(CCUIModuleCollectionViewController, viewDidLoad);
            CHHook1(CCUIModuleCollectionViewController, viewWillAppear);
        } else {
            HBLogWarn(@"Skipping Control Center module collection hooks because required methods are unavailable");
        }

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

        if (gIconScrollViewClass) {
            CHHook1(SBIconScrollView, initWithFrame);
        } else {
            HBLogWarn(@"Skipping SBIconScrollView hooks because the class is unavailable");
        }

        if ([UIApplication instancesRespondToSelector:@selector(motionEnded:withEvent:)]) {
            CHHook2(UIApplication, motionEnded, withEvent);
        } else {
            HBLogWarn(@"Skipping UIApplication motion hook because motionEnded:withEvent: is unavailable");
        }

        CHHook0(SBWiFiManager, _updateCurrentNetwork);
        CHHook0(SBWiFiManager, _linkDidChange);
        CHHook1(_UISystemGestureWindow, sendEvent);
        if ([gBuiltInRegistry legacyHomeButtonTouchStreamHookShouldBeInstalled]) {
            CHHook0(__UISystemGestureManager, _dispatchModeForExternalGestureCompletion);
        }
        CHHook2(SpringBoard, __handleHIDEvent, withUIEvent);
        CHHook1(SpringBoard, __handleHIDEvent);
        CHHook1(SpringBoard, applicationDidFinishLaunching);

        Class modernStatusBarClass = NSClassFromString(@"UIStatusBar_Modern");
        BOOL isSafeToHookStatusBarTouches =
            ([modernStatusBarClass instancesRespondToSelector:@selector(touchesBegan:withEvent:)] &&
             [modernStatusBarClass instancesRespondToSelector:@selector(touchesMoved:withEvent:)] &&
             [modernStatusBarClass instancesRespondToSelector:@selector(touchesEnded:withEvent:)] &&
             [modernStatusBarClass instancesRespondToSelector:@selector(touchesCancelled:withEvent:)]);
        if (isSafeToHookStatusBarTouches) {
            CHHook2(UIStatusBar_Modern, touchesBegan, withEvent);
            CHHook2(UIStatusBar_Modern, touchesMoved, withEvent);
            CHHook2(UIStatusBar_Modern, touchesEnded, withEvent);
            CHHook2(UIStatusBar_Modern, touchesCancelled, withEvent);
        } else {
            HBLogWarn(@"Skipping UIStatusBar_Modern touch hooks because one or more touch methods are not present");
        }
    });
}

__attribute__((constructor)) static void LATweakInitialize(void) {
    LAActivator *activator = [LAActivator sharedInstance];
    gBuiltInRegistry = [[LATBuiltInRegistry alloc] initWithActivator:activator];
#if LIBACTIVATOR_TEST_SUPPORT
    if (![LATweakTestSupport registerTests]) {
        HBLogError(@"Unable to register tweak-owned test suites");
    }
#endif
    gHIDEventSources = (NSArray<id<LATEventSourceHIDIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceHIDIngress)];
    gIconScrollViewEventSources = (NSArray<id<LATEventSourceIconScrollViewIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceIconScrollViewIngress)];
    gMotionEventSources = (NSArray<id<LATEventSourceMotionIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceMotionIngress)];
    gNetworkStateEventSources = (NSArray<id<LATEventSourceNetworkStateIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceNetworkStateIngress)];
    gStatusBarTouchEventSources = (NSArray<id<LATEventSourceStatusBarTouchIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceStatusBarTouchIngress)];
    gSystemGestureWindowEventSources = (NSArray<id<LATEventSourceSystemGestureWindowIngress>> *)[gBuiltInRegistry
        eventSourcesConformingToProtocol:@protocol(LATEventSourceSystemGestureWindowIngress)];
    LATInstallHooks();
}
