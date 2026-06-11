//
//  LATestPrivateInterfaces.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - UIApplication

@interface UIApplication (LATestPrivate)
- (id)_accessibilityFrontMostApplication;
@end

#pragma mark - SpringBoard App

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayIdentifier;
@end

#pragma mark - SpringBoard

@interface SpringBoard : UIApplication
+ (instancetype)sharedApplication;
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
- (void)suspend;
@end

#pragma mark - Lock Screen

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)remoteLock:(BOOL)lock;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode
                   finishUIUnlock:(BOOL)finishUIUnlock
                       completion:(nullable id)completion;
@end

#pragma mark - Backlight

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
- (void)_startFadeOutAnimationFromLockSource:(long long)source;
@end

#pragma mark - Automation

@interface SBSTestAutomationService : NSObject
- (void)resetToHomeScreenAnimated:(BOOL)animated;
- (void)resetToHomeScreenAnimated:(BOOL)animated useSafeTransitions:(BOOL)useSafeTransitions;
@end

NS_ASSUME_NONNULL_END
