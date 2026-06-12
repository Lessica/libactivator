//
//  LATLockScreenCameraLauncher.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATLockScreenCameraLauncher.h"

#import "LATBuiltInRegistry.h"
#import "LATRuntimeStateSource.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface CSCoverSheetViewController : UIViewController
- (BOOL)isMainPageVisible;
- (NSInteger)lastSettledPageIndex;
- (void)activateCameraViewAnimated:(BOOL)animated sendingActions:(id)actions completion:(id)completion;
- (void)activateMainPageWithCompletion:(id)completion;
@end

@interface LATLockScreenCameraLauncher ()
@property(nonatomic, weak) LATBuiltInRegistry *registry;
@end

@implementation LATLockScreenCameraLauncher

- (instancetype)initWithRegistry:(LATBuiltInRegistry *)registry {
    self = [super init];
    if (self) {
        _registry = registry;
    }
    return self;
}

- (BOOL)enqueueOpenLockScreenCamera {
    CSCoverSheetViewController *coverSheetViewController = self.registry.coverSheetViewControllerInstance;
    if (!coverSheetViewController) {
        HBLogWarn(@"Unable to open lock screen camera because CoverSheet controller is unavailable");
        return NO;
    }

    if (![coverSheetViewController
            respondsToSelector:@selector(activateCameraViewAnimated:sendingActions:completion:)]) {
        HBLogWarn(@"Unable to open lock screen camera because CoverSheet camera activation is unavailable");
        return NO;
    }

    __weak CSCoverSheetViewController *weakCoverSheetViewController = coverSheetViewController;
    LATRuntimeStateSource *runtimeStateSource = self.registry.runtimeStateSource;
    BOOL screenIsOn = runtimeStateSource ? runtimeStateSource.screenIsOn : YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        CSCoverSheetViewController *strongCoverSheetViewController = weakCoverSheetViewController;
        if (!strongCoverSheetViewController) {
            HBLogWarn(@"Unable to open lock screen camera because CoverSheet controller was released");
            return;
        }

        if (!screenIsOn && runtimeStateSource) {
            [runtimeStateSource wakeScreenForReason:@"lock screen camera"
                                         completion:^{
                                             [self activateLockScreenCameraIfNeededWithCoverSheetViewController:
                                                       strongCoverSheetViewController];
                                         }];
            return;
        }

        [self activateLockScreenCameraIfNeededWithCoverSheetViewController:strongCoverSheetViewController];
    });

    return YES;
}

- (BOOL)lockScreenCameraIsVisibleForCoverSheetViewController:(CSCoverSheetViewController *)coverSheetViewController {
    if (![coverSheetViewController respondsToSelector:@selector(isMainPageVisible)] ||
        ![coverSheetViewController respondsToSelector:@selector(lastSettledPageIndex)]) {
        return NO;
    }

    return ![coverSheetViewController isMainPageVisible] && [coverSheetViewController lastSettledPageIndex] == 1;
}

- (void)activateLockScreenCameraIfNeededWithCoverSheetViewController:
    (CSCoverSheetViewController *)coverSheetViewController {
    if (![coverSheetViewController
            respondsToSelector:@selector(activateCameraViewAnimated:sendingActions:completion:)]) {
        HBLogWarn(@"Unable to open lock screen camera because CoverSheet camera activation became unavailable");
        return;
    }

    if ([self lockScreenCameraIsVisibleForCoverSheetViewController:coverSheetViewController]) {
        HBLogDebug(@"Lock screen camera is already visible");
        return;
    }

    [coverSheetViewController activateCameraViewAnimated:YES sendingActions:nil completion:nil];
}

@end
