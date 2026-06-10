//
//  LATestEnvironment.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivator+Private.h"
#import "LAActivatorBackend.h"
#import "LAActivatorIPC.h"
#import "LAActivatorPersistence.h"
#import "LAActivatorResourceManager.h"
#import "LATouchActivityTracker.h"
#import "LATestCountingPersistence.h"
#import "LATestEventDataSource.h"
#import "LATestListener.h"
#import "LATestRecorder.h"
#import "LATestSimpleAbortListener.h"
#import "LATestTestingProtocols.h"
#import "LATestTouch.h"
#import "LATestTouchEvent.h"

#import <Activator/Activator.h>
#import <Foundation/Foundation.h>
#import <roothide.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;

@interface LATestEnvironment : NSObject
+ (void)cleanActivator:(LAActivator *)activator;
+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator;
+ (void)removeTestPlist;
+ (void)sendSyntheticTouchWithTouching:(BOOL)touching;
+ (void)waitForSyntheticTouchDelivery;
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
+ (NSString *)runtimeDebugReasonWithPrefix:(nullable NSString *)prefix activator:(LAActivator *)activator;
+ (void)performOnMainThreadSynchronously:(nullable dispatch_block_t)block;
+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval;
+ (void)waitForMainQueue;
@end

NS_ASSUME_NONNULL_END

