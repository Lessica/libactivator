//
//  LATBuiltInRegistry.h
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class SBRingerControl;
@class SBVolumeControl;
@class CSCoverSheetViewController;
@class LATButtonEventSource;
@class LATEdgeGestureEventSource;
@class LATEventDefinitionRegistry;
@class LATEventSourceRegistry;
@class LATFingerprintSensorEventSource;
@class LATForceTouchEventSource;
@class LATLockStateEventSource;
@class LATMediaEventSource;
@class LATMultiTouchEventSource;
@class LATNetworkEventSource;
@class LATPowerStateEventSource;
@class LATRuntimeStateSource;
@class LATSpringBoardIconGestureEventSource;
@class LATStatusBarEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInRegistry : NSObject

// Captured SpringBoard-owned instances
@property(nonatomic, weak, nullable) CSCoverSheetViewController *coverSheetViewControllerInstance;
@property(nonatomic, weak, nullable) SBRingerControl *ringerControlInstance;
@property(nonatomic, weak, nullable) SBVolumeControl *volumeControlInstance;

// Event sources
@property(nonatomic, strong, readonly) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readonly) LATButtonEventSource *buttonEventSource;
@property(nonatomic, strong, readonly) LATEdgeGestureEventSource *edgeGestureEventSource;
@property(nonatomic, strong, readonly) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readonly) LATEventSourceRegistry *eventSourceRegistry;
@property(nonatomic, strong, readonly, nullable) LATFingerprintSensorEventSource *fingerprintSensorEventSource;
@property(nonatomic, strong, readonly, nullable) LATForceTouchEventSource *forceTouchEventSource;
@property(nonatomic, strong, readonly) LATLockStateEventSource *lockStateEventSource;
@property(nonatomic, strong, readonly) LATMediaEventSource *mediaEventSource;
@property(nonatomic, strong, readonly) LATMultiTouchEventSource *multiTouchEventSource;
@property(nonatomic, strong, readonly) LATNetworkEventSource *networkEventSource;
@property(nonatomic, strong, readonly) LATPowerStateEventSource *powerStateEventSource;
@property(nonatomic, strong, readonly) LATSpringBoardIconGestureEventSource *springBoardIconGestureEventSource;
@property(nonatomic, strong, readonly) LATStatusBarEventSource *statusBarEventSource;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (void)startEventSources;
- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason;
- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled;

@end

NS_ASSUME_NONNULL_END
