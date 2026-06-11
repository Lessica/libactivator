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

extern void MRMediaRemoteSetWantsNowPlayingNotifications(Boolean wantsNotifications) __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t queue,
                                                           void (^completion)(CFStringRef displayID))
    __attribute__((weak_import));
extern void MRMediaRemoteGetNowPlayingApplicationPID(dispatch_queue_t queue, void (^completion)(int PID))
    __attribute__((weak_import));
extern CFStringRef SBSCopyDisplayIdentifierForProcessID(pid_t PID) __attribute__((weak_import));

@interface LATSystemNowPlayingApplicationLauncher ()
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;
@end

@implementation LATSystemNowPlayingApplicationLauncher

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher {
    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
    }
    return self;
}

- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName {
    if (MRMediaRemoteSetWantsNowPlayingNotifications) {
        MRMediaRemoteSetWantsNowPlayingNotifications(true);
    }

    if (MRMediaRemoteGetNowPlayingApplicationDisplayID) {
        [self requestNowPlayingApplicationDisplayIdentifierForListenerName:listenerName ?: @""];
        return YES;
    }

    if (MRMediaRemoteGetNowPlayingApplicationPID && SBSCopyDisplayIdentifierForProcessID) {
        [self requestNowPlayingApplicationProcessIdentifierForListenerName:listenerName ?: @""];
        return YES;
    }

    HBLogError(@"Unable to launch now-playing application for system action %@ because MediaRemote identity APIs are "
               @"unavailable",
               listenerName ?: @"");
    return NO;
}

- (void)requestNowPlayingApplicationDisplayIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationDisplayID(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(CFStringRef displayID) {
            NSString *identifier = [(__bridge NSString *)displayID copy];
            if (identifier.length > 0) {
                [self launchApplicationWithIdentifier:identifier listenerName:listenerName];
                return;
            }

            HBLogWarn(@"MediaRemote returned no now-playing application display identifier for system action %@",
                      listenerName ?: @"");
            if (MRMediaRemoteGetNowPlayingApplicationPID && SBSCopyDisplayIdentifierForProcessID) {
                [self requestNowPlayingApplicationProcessIdentifierForListenerName:listenerName];
            }
        });
}

- (void)requestNowPlayingApplicationProcessIdentifierForListenerName:(NSString *)listenerName {
    MRMediaRemoteGetNowPlayingApplicationPID(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int PID) {
        if (PID <= 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application process identifier for system action %@",
                      listenerName ?: @"");
            return;
        }

        CFStringRef displayID = SBSCopyDisplayIdentifierForProcessID((pid_t)PID);
        NSString *identifier = displayID ? CFBridgingRelease(displayID) : nil;
        if (identifier.length == 0) {
            HBLogError(@"Unable to resolve now-playing application display identifier for process %d", PID);
            return;
        }

        [self launchApplicationWithIdentifier:identifier listenerName:listenerName];
    });
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
