//
//  LATSystemVolumeHUDPresenter.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemVolumeHUDPresenter.h"

#import <HBLog.h>

@interface SBVolumeControl : NSObject
- (float)_effectiveVolume;
- (void)_presentVolumeHUDWithVolume:(float)volume;
@end

@interface LATSystemVolumeHUDPresenter ()
@property(nonatomic, weak) id<LATSpringBoardInstanceProviding> springBoardInstanceProvider;
@end

@implementation LATSystemVolumeHUDPresenter

- (instancetype)initWithSpringBoardInstanceProvider:(id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider {
    self = [super init];
    if (self) {
        _springBoardInstanceProvider = springBoardInstanceProvider;
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

    SBVolumeControl *volumeControl = self.springBoardInstanceProvider.volumeControlInstance;
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
