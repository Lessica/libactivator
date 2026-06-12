//
//  LATSystemVolumeHUDPresenter.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemVolumeHUDPresenter.h"

#import "LATBuiltInRegistry.h"

#import <HBLog.h>

@interface SBVolumeControl : NSObject
- (float)_effectiveVolume;
- (void)_presentVolumeHUDWithVolume:(float)volume;
@end

@interface LATSystemVolumeHUDPresenter ()
@property(nonatomic, weak) LATBuiltInRegistry *registry;
@end

@implementation LATSystemVolumeHUDPresenter

- (instancetype)initWithRegistry:(LATBuiltInRegistry *)registry {
    self = [super init];
    if (self) {
        _registry = registry;
    }
    return self;
}

- (BOOL)presentVolumeHUDForListenerName:(NSString *)listenerName {
    if (![NSThread isMainThread]) {
        __block BOOL presented = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            presented = [self presentVolumeHUDForListenerName:listenerName];
        });
        return presented;
    }

    SBVolumeControl *volumeControl = self.registry.volumeControlInstance;
    if (!volumeControl) {
        HBLogError(@"Unable to present volume HUD for system action %@ because SBVolumeControl was not captured",
                   listenerName ?: @"");
        return NO;
    }

    if (![volumeControl respondsToSelector:@selector(_presentVolumeHUDWithVolume:)]) {
        HBLogError(@"SBVolumeControl does not support _presentVolumeHUDWithVolume:");
        return NO;
    }

    float volume = 0.5f;
    if ([volumeControl respondsToSelector:@selector(_effectiveVolume)]) {
        volume = [volumeControl _effectiveVolume];
    }

    [volumeControl _presentVolumeHUDWithVolume:volume];
    return YES;
}

@end
