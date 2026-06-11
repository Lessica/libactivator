//
//  LATSystemNowPlayingApplicationLauncher.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemNowPlayingApplicationLauncher.h"

#import "LATApplicationLauncher.h"
#import "LATMediaEventSource.h"

#import <HBLog.h>

@interface LATSystemNowPlayingApplicationLauncher ()
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;
@property(nonatomic, weak) LATMediaEventSource *mediaEventSource;
@end

@implementation LATSystemNowPlayingApplicationLauncher

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher {
    return [self initWithApplicationLauncher:applicationLauncher mediaEventSource:nil];
}

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                           mediaEventSource:(LATMediaEventSource *)mediaEventSource {
    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
        _mediaEventSource = mediaEventSource;
    }
    return self;
}

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName {
    LATMediaEventSource *mediaEventSource = self.mediaEventSource;
    if (!mediaEventSource) {
        HBLogError(@"Unable to launch now-playing application for system action %@ because the media event "
                   @"source is unavailable",
                   listenerName ?: @"");
        return NO;
    }

    NSString *listenerNameToLaunch = [listenerName copy] ?: @"";
    return [mediaEventSource requestNowPlayingApplicationDisplayIdentifierWithCompletion:^(NSString *identifier) {
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
