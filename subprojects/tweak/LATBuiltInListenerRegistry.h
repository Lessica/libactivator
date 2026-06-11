//
//  LATBuiltInListenerRegistry.h
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class SBRingerControl;
@class SBVolumeControl;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInListenerRegistry : NSObject
@property(class, nonatomic, weak, nullable) SBVolumeControl *volumeControlInstance;
@property(class, nonatomic, weak, nullable) SBRingerControl *ringerControlInstance;
+ (void)registerWithActivator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
