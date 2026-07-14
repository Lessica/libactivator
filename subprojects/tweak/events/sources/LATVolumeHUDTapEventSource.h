//
//  LATVolumeHUDTapEventSource.h
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

@interface LATVolumeHUDTapEventSource : NSObject <LATEventSource, LATEventSourceVolumeHUDViewIngress>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider NS_DESIGNATED_INITIALIZER;

- (void)noteVolumeHUDSliderContainerViewDidLoad:(UIView *)sliderContainerView;

#if DEBUG
- (BOOL)la_testingHandleTapState:(UIGestureRecognizerState)state;
- (NSUInteger)la_testingKnownSliderContainerViewCount;
- (BOOL)la_testingIsInstalledInSliderContainerView:(UIView *)sliderContainerView;
#endif

@end

NS_ASSUME_NONNULL_END
