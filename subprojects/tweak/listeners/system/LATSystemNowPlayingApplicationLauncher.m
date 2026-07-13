//
//  LATSystemNowPlayingApplicationLauncher.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemNowPlayingApplicationLauncher.h"

#import "LATApplicationLauncher.h"

#import <HBLog.h>

@interface LATSystemNowPlayingApplicationLauncher ()
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;
@property(nonatomic, weak, nullable) id<LATNowPlayingProviding> nowPlayingProvider;
@end

@implementation LATSystemNowPlayingApplicationLauncher

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         nowPlayingProvider:(id<LATNowPlayingProviding>)nowPlayingProvider {
    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
        _nowPlayingProvider = nowPlayingProvider;
    }
    return self;
}

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName {
    id<LATNowPlayingProviding> nowPlayingProvider = self.nowPlayingProvider;
    if (!nowPlayingProvider) {
        HBLogError(@"Unable to launch now-playing application for system action %@ because the media event "
                   @"source is unavailable",
                   listenerName ?: @"");
        return NO;
    }

    NSString *listenerNameToLaunch = [listenerName copy] ?: @"";
    return [nowPlayingProvider requestNowPlayingApplicationDisplayIdentifierWithCompletion:^(NSString *identifier) {
        if (identifier.length == 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application identity for system action %@",
                      listenerNameToLaunch ?: @"");
            return;
        }

        [self launchApplicationWithIdentifier:identifier listenerName:listenerNameToLaunch];
    }];
}

- (void)launchApplicationWithIdentifier:(NSString *)displayIdentifier listenerName:(NSString *)listenerName {
    if (displayIdentifier.length == 0) {
        return;
    }

    if (![self.applicationLauncher enqueueLaunchApplicationWithIdentifier:displayIdentifier unlockDevice:YES]) {
        HBLogError(@"Unable to enqueue now-playing application %@ for system action %@", displayIdentifier,
                   listenerName ?: @"");
    }
}

@end
