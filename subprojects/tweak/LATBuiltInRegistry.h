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
@class LATLockStateEventSource;
@class LATMediaEventSource;
@class LATPowerStateEventSource;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInRegistry : NSObject

@property(nonatomic, weak, nullable) SBVolumeControl *volumeControlInstance;
@property(nonatomic, weak, nullable) SBRingerControl *ringerControlInstance;
@property(nonatomic, weak, nullable) CSCoverSheetViewController *coverSheetViewControllerInstance;

@property(nonatomic, strong, readonly) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readonly) LATLockStateEventSource *lockStateEventSource;
@property(nonatomic, strong, readonly) LATPowerStateEventSource *powerStateEventSource;
@property(nonatomic, strong, readonly) LATMediaEventSource *mediaEventSource;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (void)startEventSources;

@end

NS_ASSUME_NONNULL_END
