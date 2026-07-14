//
//  LATLockScreenClockEventSource.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"
#import "LATEventSourceIngress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATLockScreenClockEventSource : NSObject <LATEventSource, LATEventSourceLockScreenClockViewIngress>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider NS_DESIGNATED_INITIALIZER;

- (void)noteLockScreenClockViewDidLoad:(UIView *)clockView;
- (void)notePreciseLockScreenClockViewDidLoad:(UIView *)clockView;

#if DEBUG
- (BOOL)la_testingHandleRecognizerState:(UIGestureRecognizerState)state eventName:(NSString *)eventName;
- (NSUInteger)la_testingKnownClockViewCount;
- (nullable NSArray<UIGestureRecognizer *> *)la_testingInstalledRecognizersInClockView:(UIView *)clockView;
#endif

@end

NS_ASSUME_NONNULL_END
