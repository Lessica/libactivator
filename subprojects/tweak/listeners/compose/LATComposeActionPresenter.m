//
//  LATComposeActionPresenter.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "compose/LATComposeActionPresenter.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface MFMailComposeViewController : UINavigationController
- (void)setMailComposeDelegate:(id)delegate;
@end

@interface MFMessageComposeViewController : UINavigationController
- (void)setMessageComposeDelegate:(id)delegate;
@end

@interface SBSSystemNotesPresentationConfiguration : NSObject
- (instancetype)initWithSceneBundleIdentifier:(NSString *)sceneBundleIdentifier
                                 userActivity:(nullable id)userActivity
                    preferredPresentationMode:(NSInteger)preferredPresentationMode;
@end

@interface SBSSystemNotesPresentationHandle : NSObject
- (instancetype)initWithConfiguration:(SBSSystemNotesPresentationConfiguration *)configuration;
- (void)activate;
@end

@interface SBSRemoteAlertDefinition : NSObject
- (instancetype)initWithServiceName:(NSString *)serviceName viewControllerClassName:(NSString *)viewControllerClassName;
@end

@interface SBSRemoteAlertConfigurationContext : NSObject
@end

@interface SBSRemoteAlertActivationContext : NSObject
@end

@interface SBSRemoteAlertHandle : NSObject
+ (instancetype)newHandleWithDefinition:(SBSRemoteAlertDefinition *)definition
                   configurationContext:(SBSRemoteAlertConfigurationContext *)configurationContext;
- (void)activateWithContext:(SBSRemoteAlertActivationContext *)activationContext;
- (void)registerObserver:(id)observer;
- (void)unregisterObserver:(id)observer;
@end

@interface LATComposeRootViewController : UIViewController
@end

@implementation LATComposeRootViewController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end

@interface LATComposeActionPresenter ()

// Presentation window state
@property(nonatomic, strong, nullable) UIWindow *presentationWindow;
@property(nonatomic, strong, nullable) UIWindow *previousKeyWindow;
@property(nonatomic, strong, nullable) UIViewController *presentedComposeViewController;

// System Paper remote alert state
@property(nonatomic, strong, nullable) SBSRemoteAlertHandle *systemPaperRemoteAlertHandle;

@end

@implementation LATComposeActionPresenter

#pragma mark - Public API

- (BOOL)performComposeAction:(LATComposeActionKind)kind listenerName:(NSString *)listenerName {
    if (kind == LATComposeActionKindNote) {
        return [self activateSystemPaperForListenerName:listenerName];
    }

    if ([self dismissPresentedComposeViewControllerAnimated:YES]) {
        return YES;
    }

    UIViewController *composeViewController = [self composeViewControllerForKind:kind listenerName:listenerName];
    if (!composeViewController) {
        return NO;
    }
    return [self presentComposeViewController:composeViewController listenerName:listenerName];
}

#pragma mark - MessageUI Compose

- (nullable UIViewController *)composeViewControllerForKind:(LATComposeActionKind)kind
                                               listenerName:(NSString *)listenerName {
    switch (kind) {
    case LATComposeActionKindMail:
        return [self mailComposeViewControllerForListenerName:listenerName];
    case LATComposeActionKindText:
        return [self messageComposeViewControllerForListenerName:listenerName];
    case LATComposeActionKindNote:
        return nil;
    }
}

- (BOOL)loadFrameworkAtPath:(NSString *)frameworkPath listenerName:(NSString *)listenerName {
    NSBundle *frameworkBundle = [NSBundle bundleWithPath:frameworkPath];
    if (frameworkBundle.loaded) {
        return YES;
    }

    NSError *error = nil;
    if ([frameworkBundle loadAndReturnError:&error]) {
        return YES;
    }

    HBLogError(@"Failed to load framework %@ for compose action %@: %@", frameworkPath ?: @"", listenerName ?: @"",
               error.localizedDescription ?: @"unknown error");
    return NO;
}

- (nullable UIViewController *)mailComposeViewControllerForListenerName:(NSString *)listenerName {
    if (![self loadFrameworkAtPath:@"/System/Library/Frameworks/MessageUI.framework" listenerName:listenerName]) {
        return nil;
    }

    Class composeClass = NSClassFromString(@"MFMailComposeViewController");
    if (!composeClass) {
        HBLogError(@"MFMailComposeViewController is unavailable for compose action %@", listenerName ?: @"");
        return nil;
    }

    MFMailComposeViewController *composeViewController = [[composeClass alloc] init];
    if ([composeViewController respondsToSelector:@selector(setModalPresentationStyle:)]) {
        composeViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    if ([composeViewController respondsToSelector:@selector(setMailComposeDelegate:)]) {
        [composeViewController setMailComposeDelegate:self];
    }
    return composeViewController;
}

- (nullable UIViewController *)messageComposeViewControllerForListenerName:(NSString *)listenerName {
    if (![self loadFrameworkAtPath:@"/System/Library/Frameworks/MessageUI.framework" listenerName:listenerName]) {
        return nil;
    }

    Class composeClass = NSClassFromString(@"MFMessageComposeViewController");
    if (!composeClass) {
        HBLogError(@"MFMessageComposeViewController is unavailable for compose action %@", listenerName ?: @"");
        return nil;
    }

    MFMessageComposeViewController *composeViewController = [[composeClass alloc] init];
    if ([composeViewController respondsToSelector:@selector(setModalPresentationStyle:)]) {
        composeViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    if ([composeViewController respondsToSelector:@selector(setMessageComposeDelegate:)]) {
        [composeViewController setMessageComposeDelegate:self];
    }
    return composeViewController;
}

#pragma mark - System Paper

- (BOOL)activateSystemPaperForListenerName:(NSString *)listenerName {
    if ([self shouldUseSystemNotesPresentation]) {
        return [self activateSystemNotesPresentationForListenerName:listenerName];
    }

    return [self activateSystemPaperRemoteAlertForListenerName:listenerName];
}

- (BOOL)shouldUseSystemNotesPresentation {
    UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
    return idiom == UIUserInterfaceIdiomPad || idiom == UIUserInterfaceIdiomMac;
}

- (BOOL)activateSystemNotesPresentationForListenerName:(NSString *)listenerName {
    Class configurationClass = NSClassFromString(@"SBSSystemNotesPresentationConfiguration");
    Class handleClass = NSClassFromString(@"SBSSystemNotesPresentationHandle");
    if (!configurationClass || !handleClass) {
        HBLogError(@"System Notes presentation classes are unavailable for compose action %@", listenerName ?: @"");
        return NO;
    }

    SBSSystemNotesPresentationConfiguration *configuration =
        [[configurationClass alloc] initWithSceneBundleIdentifier:@"com.apple.mobilenotes"
                                                     userActivity:nil
                                        preferredPresentationMode:0];
    SBSSystemNotesPresentationHandle *handle = [[handleClass alloc] initWithConfiguration:configuration];
    if (![handle respondsToSelector:@selector(activate)]) {
        HBLogError(@"System Notes presentation handle cannot activate compose action %@", listenerName ?: @"");
        return NO;
    }

    [handle activate];
    HBLogDebug(@"Activated System Notes presentation for compose action %@", listenerName ?: @"");
    return YES;
}

- (BOOL)activateSystemPaperRemoteAlertForListenerName:(NSString *)listenerName {
    if (self.systemPaperRemoteAlertHandle) {
        HBLogDebug(@"System Paper remote alert already exists for compose action %@", listenerName ?: @"");
        return YES;
    }

    Class definitionClass = NSClassFromString(@"SBSRemoteAlertDefinition");
    Class configurationContextClass = NSClassFromString(@"SBSRemoteAlertConfigurationContext");
    Class handleClass = NSClassFromString(@"SBSRemoteAlertHandle");
    Class activationContextClass = NSClassFromString(@"SBSRemoteAlertActivationContext");
    if (!definitionClass || !configurationContextClass || !handleClass || !activationContextClass) {
        HBLogError(@"System Paper remote alert classes are unavailable for compose action %@", listenerName ?: @"");
        return NO;
    }

    SBSRemoteAlertDefinition *definition =
        [[definitionClass alloc] initWithServiceName:@"com.apple.SystemPaperViewService"
                             viewControllerClassName:@"ViewController"];
    SBSRemoteAlertConfigurationContext *configurationContext = [[configurationContextClass alloc] init];
    SBSRemoteAlertHandle *handle = [handleClass newHandleWithDefinition:definition
                                                   configurationContext:configurationContext];
    SBSRemoteAlertActivationContext *activationContext = [[activationContextClass alloc] init];
    if (![handle respondsToSelector:@selector(activateWithContext:)]) {
        HBLogError(@"System Paper remote alert handle cannot activate compose action %@", listenerName ?: @"");
        return NO;
    }

    [handle registerObserver:self];
    [handle activateWithContext:activationContext];
    self.systemPaperRemoteAlertHandle = handle;
    HBLogDebug(@"Activated System Paper remote alert for compose action %@", listenerName ?: @"");
    return YES;
}

- (void)cleanupSystemPaperRemoteAlertHandle:(SBSRemoteAlertHandle *)handle {
    if (handle != self.systemPaperRemoteAlertHandle) {
        return;
    }
    if ([handle respondsToSelector:@selector(unregisterObserver:)]) {
        [handle unregisterObserver:self];
    }
    self.systemPaperRemoteAlertHandle = nil;
}

#pragma mark - Presentation Window

- (BOOL)presentComposeViewController:(UIViewController *)composeViewController listenerName:(NSString *)listenerName {
    if (!composeViewController) {
        return NO;
    }

    UIWindow *keyWindow = [self currentKeyWindow];
    UIWindow *presentationWindow = self.presentationWindow;
    if (!presentationWindow) {
        UIWindowScene *windowScene = keyWindow.windowScene;
        if (windowScene) {
            presentationWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
        } else {
            presentationWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        presentationWindow.windowLevel = UIWindowLevelStatusBar;
        self.presentationWindow = presentationWindow;
    }

    if (keyWindow != presentationWindow) {
        self.previousKeyWindow = keyWindow;
    }

    LATComposeRootViewController *rootViewController = [[LATComposeRootViewController alloc] init];
    presentationWindow.rootViewController = rootViewController;
    [presentationWindow makeKeyAndVisible];

    self.presentedComposeViewController = composeViewController;
    [rootViewController presentViewController:composeViewController animated:YES completion:nil];
    HBLogDebug(@"Presented compose action %@", listenerName ?: @"");
    return YES;
}

- (nullable UIWindow *)currentKeyWindow {
    NSSet<UIScene *> *connectedScenes = UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }
    return nil;
}

- (BOOL)dismissPresentedComposeViewControllerAnimated:(BOOL)animated {
    if (!self.presentationWindow && !self.presentedComposeViewController) {
        return NO;
    }

    UIViewController *rootViewController = self.presentationWindow.rootViewController;
    void (^cleanup)(void) = ^{
        [self.previousKeyWindow makeKeyWindow];
        self.previousKeyWindow = nil;
        self.presentedComposeViewController = nil;
        self.presentationWindow.hidden = YES;
        self.presentationWindow.rootViewController = nil;
        self.presentationWindow = nil;
    };

    if (rootViewController.presentedViewController) {
        [rootViewController dismissViewControllerAnimated:animated completion:cleanup];
    } else {
        cleanup();
    }
    return YES;
}

#pragma mark - MessageUI Delegates

- (void)messageComposeViewController:(UIViewController *)controller didFinishWithResult:(NSInteger)result {
    (void)controller;
    (void)result;
    [self dismissPresentedComposeViewControllerAnimated:YES];
}

- (void)mailComposeController:(UIViewController *)controller
          didFinishWithResult:(NSInteger)result
                        error:(NSError *)error {
    (void)controller;
    (void)result;
    (void)error;
    [self dismissPresentedComposeViewControllerAnimated:YES];
}

#pragma mark - Remote Alert Observer

- (void)remoteAlertHandleDidActivate:(SBSRemoteAlertHandle *)handle {
    (void)handle;
    HBLogDebug(@"System Paper remote alert did activate");
}

- (void)remoteAlertHandleDidDeactivate:(SBSRemoteAlertHandle *)handle {
    [self cleanupSystemPaperRemoteAlertHandle:handle];
}

- (void)remoteAlertHandle:(SBSRemoteAlertHandle *)handle didInvalidateWithError:(NSError *)error {
    HBLogError(@"System Paper remote alert invalidated: %@", error.localizedDescription ?: @"unknown error");
    [self cleanupSystemPaperRemoteAlertHandle:handle];
}

@end
