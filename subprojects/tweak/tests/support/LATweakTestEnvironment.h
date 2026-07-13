//
//  LATweakTestEnvironment.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LAActivator;

NS_ASSUME_NONNULL_BEGIN

@interface LATweakTestEnvironment : NSObject

#pragma mark - Cleanup

+ (void)cleanActivator:(LAActivator *)activator;

#pragma mark - Device Automation

+ (BOOL)resetHomeScreen;
+ (BOOL)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier;
+ (BOOL)prepareApplicationModeWithBundleIdentifier:(NSString *)bundleIdentifier
                                         activator:(LAActivator *)activator
                                          attempts:(NSUInteger)attempts;
+ (BOOL)suspendApplication;
+ (BOOL)lockDevice;
+ (BOOL)unlockDeviceWithPasscode:(nullable NSString *)passcode;
+ (BOOL)isDeviceLocked;
+ (nullable NSString *)frontMostDisplayIdentifier;
+ (BOOL)waitForFrontMostApplicationWithBundleIdentifier:(NSString *)bundleIdentifier timeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
