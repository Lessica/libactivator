//
//  LATSystemCenterController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATRuntimeStateSource;
@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemCenterController : NSObject

- (instancetype)initWithRuntimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource;

+ (void)noteModuleCollectionViewControllerDidLoad:(UIViewController *)viewController;
+ (void)noteModuleCollectionViewControllerWillAppear:(UIViewController *)viewController;
- (BOOL)activateControlCenterForListenerName:(NSString *)listenerName;
- (BOOL)showNowPlayingControlsForListenerName:(NSString *)listenerName;
- (BOOL)activateNotificationCenterForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
