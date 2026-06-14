//
//  LATMediaEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMediaEventSource.h"

#import "LAActivator+Private.h"
#import "LATQueueAssertions.h"
#import "MediaRemote+Private.h"

#import <HBLog.h>

typedef NSString *AVSystemControllerKey;

static AVSystemControllerKey const AVSystemController_HeadphoneJackIsConnectedDidChangeNotification =
    @"AVSystemController_HeadphoneJackIsConnectedDidChangeNotification";
static AVSystemControllerKey const AVSystemController_HeadphoneJackIsConnectedAttribute =
    @"AVSystemController_HeadphoneJackIsConnectedAttribute";
static AVSystemControllerKey const AVSystemController_ActiveAudioRouteDidChangeNotification =
    @"AVSystemController_ActiveAudioRouteDidChangeNotification";
static AVSystemControllerKey const AVSystemController_PickableRoutesDidChangeNotification =
    @"AVSystemController_PickableRoutesDidChangeNotification";

static NSString *const LATNowPlayingInfoChangedEventName = @"libactivator.now-playing.info-changed";
static NSString *const LATNowPlayingPlayingEventName = @"libactivator.now-playing.playing";
static NSString *const LATNowPlayingPausedEventName = @"libactivator.now-playing.paused";

extern void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t queue,
                                                           void (^completion)(CFStringRef displayID))
    __attribute__((weak_import));
extern CFStringRef SBSCopyDisplayIdentifierForProcessID(pid_t PID) __attribute__((weak_import));

@interface AVSystemController : NSObject
+ (instancetype)sharedAVSystemController;
- (id)attributeForKey:(AVSystemControllerKey)attributeKey;
@end

@interface LATMediaEventSource ()

// Lifecycle
@property(nonatomic, assign) BOOL started;

// Headset state
@property(nonatomic, assign) BOOL hasKnownHeadsetState;
@property(nonatomic, assign, getter=isHeadsetConnected) BOOL headsetConnected;

// Now playing playback state
@property(nonatomic, assign) BOOL hasKnownNowPlayingPlaybackState;
@property(nonatomic, assign, getter=isNowPlayingApplicationPlaying) BOOL nowPlayingApplicationPlaying;

// Observation tokens
@property(nonatomic, strong, nullable) id<NSObject> activeAudioRouteObserver;
@property(nonatomic, strong, nullable) id<NSObject> headphoneStateObserver;
@property(nonatomic, strong, nullable) id<NSObject> nowPlayingApplicationIsPlayingObserver;
@property(nonatomic, strong, nullable) id<NSObject> nowPlayingInfoObserver;
@property(nonatomic, strong, nullable) id<NSObject> pickableRoutesObserver;
@property(nonatomic, strong, nullable) id<NSObject> routeStatusObserver;
@property(nonatomic, strong, nullable) id<NSObject> systemPickableRoutesObserver;

// Dispatch queues
@property(nonatomic, strong) dispatch_queue_t mediaRemoteQueue;

@end

@implementation LATMediaEventSource

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0);
        _mediaRemoteQueue = dispatch_queue_create("libactivator.mediaremote", attr);
    }
    return self;
}

- (void)start {
    LATAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownHeadsetStateWithoutSendingEvent];
    [self startMediaRemoteRouteMonitoring];
    [self startMediaRemoteNowPlayingMonitoring];
    [self startAVSystemControllerRouteMonitoring];
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    if (_routeStatusObserver) {
        [notificationCenter removeObserver:_routeStatusObserver];
    }
    if (_pickableRoutesObserver) {
        [notificationCenter removeObserver:_pickableRoutesObserver];
    }
    if (_nowPlayingInfoObserver) {
        [notificationCenter removeObserver:_nowPlayingInfoObserver];
    }
    if (_nowPlayingApplicationIsPlayingObserver) {
        [notificationCenter removeObserver:_nowPlayingApplicationIsPlayingObserver];
    }
    if (_activeAudioRouteObserver) {
        [notificationCenter removeObserver:_activeAudioRouteObserver];
    }
    if (_systemPickableRoutesObserver) {
        [notificationCenter removeObserver:_systemPickableRoutesObserver];
    }
    if (_headphoneStateObserver) {
        [notificationCenter removeObserver:_headphoneStateObserver];
    }
}

#pragma mark - Now Playing Identity

- (BOOL)requestNowPlayingApplicationDisplayIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    LATAssertMainQueue();
    if (!completion) {
        return NO;
    }

    MRMediaRemoteSetWantsNowPlayingNotifications(true);

    if (MRMediaRemoteGetNowPlayingApplicationDisplayID) {
        [self requestMediaRemoteDisplayIdentifierWithCompletion:completion];
        return YES;
    }

    if (SBSCopyDisplayIdentifierForProcessID) {
        [self requestMediaRemoteProcessIdentifierWithCompletion:completion];
        return YES;
    }

    HBLogError(@"Unable to request now-playing application identity because required APIs are unavailable");
    return NO;
}

- (void)requestMediaRemoteDisplayIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    MRMediaRemoteGetNowPlayingApplicationDisplayID(self.mediaRemoteQueue, ^(CFStringRef displayID) {
        NSString *identifier = [(__bridge NSString *)displayID copy];
        if (identifier.length > 0) {
            [self finishNowPlayingApplicationIdentityRequestWithIdentifier:identifier completion:completion];
            return;
        }

        HBLogWarn(@"MediaRemote returned no now-playing application display identifier");
        if (SBSCopyDisplayIdentifierForProcessID) {
            [self requestMediaRemoteProcessIdentifierWithCompletion:completion];
            return;
        }

        [self finishNowPlayingApplicationIdentityRequestWithIdentifier:nil completion:completion];
    });
}

- (void)requestMediaRemoteProcessIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    MRMediaRemoteGetNowPlayingApplicationPID(self.mediaRemoteQueue, ^(int PID) {
        if (PID <= 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application process identifier");
            [self finishNowPlayingApplicationIdentityRequestWithIdentifier:nil completion:completion];
            return;
        }

        CFStringRef displayID = SBSCopyDisplayIdentifierForProcessID((pid_t)PID);
        NSString *identifier = displayID ? CFBridgingRelease(displayID) : nil;
        if (identifier.length == 0) {
            HBLogError(@"Unable to resolve now-playing application display identifier for process %d", PID);
            [self finishNowPlayingApplicationIdentityRequestWithIdentifier:nil completion:completion];
            return;
        }

        [self finishNowPlayingApplicationIdentityRequestWithIdentifier:identifier completion:completion];
    });
}

- (void)finishNowPlayingApplicationIdentityRequestWithIdentifier:(NSString *)identifier
                                                      completion:(LATNowPlayingApplicationDisplayIdentifierCompletion)
                                                                     completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(identifier);
    });
}

#pragma mark - Monitoring

- (void)startMediaRemoteRouteMonitoring {
    LATAssertMainQueue();

    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    __weak typeof(self) weakSelf = self;
    self.routeStatusObserver = [notificationCenter
        addObserverForName:(__bridge NSNotificationName)kMRMediaRemoteRouteStatusDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf handleMediaRemoteRouteNotification:notification];
                }];
    self.pickableRoutesObserver = [notificationCenter
        addObserverForName:(__bridge NSNotificationName)kMRMediaRemotePickableRoutesDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf handleMediaRemoteRouteNotification:notification];
                }];

    MRMediaRemoteSetWantsRouteChangeNotifications(true);
}

- (void)startMediaRemoteNowPlayingMonitoring {
    LATAssertMainQueue();

    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    __weak typeof(self) weakSelf = self;
    self.nowPlayingInfoObserver = [notificationCenter
        addObserverForName:(__bridge NSNotificationName)kMRMediaRemoteNowPlayingInfoDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *notification) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf handleNowPlayingInfoDidChangeNotification];
                }];
    self.nowPlayingApplicationIsPlayingObserver = [notificationCenter
        addObserverForName:(__bridge NSNotificationName)
                               kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf handleNowPlayingApplicationIsPlayingDidChangeNotification:notification];
                }];

    MRMediaRemoteSetWantsNowPlayingNotifications(true);
    [self refreshKnownNowPlayingPlaybackStateWithoutSendingEvent];
}

- (void)startAVSystemControllerRouteMonitoring {
    LATAssertMainQueue();

    AVSystemController *systemController = [self sharedAVSystemController];
    if (!systemController) {
        return;
    }

    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    __weak typeof(self) weakSelf = self;

    self.activeAudioRouteObserver =
        [notificationCenter addObserverForName:AVSystemController_ActiveAudioRouteDidChangeNotification
                                        object:systemController
                                         queue:NSOperationQueue.mainQueue
                                    usingBlock:^(__unused NSNotification *notification) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        [strongSelf handlePotentialHeadsetStateChange];
                                    }];
    self.systemPickableRoutesObserver =
        [notificationCenter addObserverForName:AVSystemController_PickableRoutesDidChangeNotification
                                        object:systemController
                                         queue:NSOperationQueue.mainQueue
                                    usingBlock:^(__unused NSNotification *notification) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        [strongSelf handlePotentialHeadsetStateChange];
                                    }];
    self.headphoneStateObserver =
        [notificationCenter addObserverForName:AVSystemController_HeadphoneJackIsConnectedDidChangeNotification
                                        object:nil
                                         queue:NSOperationQueue.mainQueue
                                    usingBlock:^(__unused NSNotification *notification) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        [strongSelf handlePotentialHeadsetStateChange];
                                    }];
}

#pragma mark - State

- (void)handleMediaRemoteRouteNotification:(NSNotification *)notification {
    LATAssertMainQueue();

    HBLogInfo(@"MediaRemote route notification for media event source: name=%@ object=%@ userInfo=%@",
              notification.name ?: @"", notification.object ?: @"", notification.userInfo ?: @{});
    [self handlePotentialHeadsetStateChange];
}

- (void)handleNowPlayingInfoDidChangeNotification {
    LATAssertMainQueue();

    __weak typeof(self) weakSelf = self;
    MRMediaRemoteGetNowPlayingInfo(self.mediaRemoteQueue, ^(__unused CFDictionaryRef information) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf sendMediaEventWithName:LATNowPlayingInfoChangedEventName];
        });
    });
}

- (void)handleNowPlayingApplicationIsPlayingDidChangeNotification:(NSNotification *)notification {
    LATAssertMainQueue();

    id value = notification.userInfo[(__bridge NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey];
    if ([value respondsToSelector:@selector(boolValue)]) {
        [self handlePotentialNowPlayingPlaybackState:[value boolValue]];
        return;
    }

    [self requestNowPlayingPlaybackStateWithCompletion:^(BOOL isPlaying) {
        [self handlePotentialNowPlayingPlaybackState:isPlaying];
    }];
}

- (void)handlePotentialNowPlayingPlaybackState:(BOOL)isPlaying {
    LATAssertMainQueue();

    if (!self.hasKnownNowPlayingPlaybackState) {
        self.hasKnownNowPlayingPlaybackState = YES;
        self.nowPlayingApplicationPlaying = isPlaying;
        return;
    }

    if (self.nowPlayingApplicationPlaying == isPlaying) {
        return;
    }

    self.nowPlayingApplicationPlaying = isPlaying;
    [self sendMediaEventWithName:isPlaying ? LATNowPlayingPlayingEventName : LATNowPlayingPausedEventName];
}

- (void)handlePotentialHeadsetStateChange {
    LATAssertMainQueue();

    BOOL headsetConnected = NO;
    if (![self readHeadsetConnected:&headsetConnected]) {
        HBLogDebug(@"Unable to read headset connection state for media event source");
        return;
    }

    if (!self.hasKnownHeadsetState) {
        self.hasKnownHeadsetState = YES;
        self.headsetConnected = headsetConnected;
        return;
    }

    if (self.headsetConnected == headsetConnected) {
        return;
    }

    self.headsetConnected = headsetConnected;
    [self sendHeadsetEventForConnectedState:headsetConnected];
}

- (void)refreshKnownHeadsetStateWithoutSendingEvent {
    LATAssertMainQueue();

    BOOL headsetConnected = NO;
    if (![self readHeadsetConnected:&headsetConnected]) {
        return;
    }
    self.hasKnownHeadsetState = YES;
    self.headsetConnected = headsetConnected;
}

- (void)refreshKnownNowPlayingPlaybackStateWithoutSendingEvent {
    LATAssertMainQueue();

    [self requestNowPlayingPlaybackStateWithCompletion:^(BOOL isPlaying) {
        if (self.hasKnownNowPlayingPlaybackState) {
            return;
        }
        self.hasKnownNowPlayingPlaybackState = YES;
        self.nowPlayingApplicationPlaying = isPlaying;
    }];
}

- (void)requestNowPlayingPlaybackStateWithCompletion:(void (^)(BOOL isPlaying))completion {
    LATAssertMainQueue();
    NSParameterAssert(completion);

    MRMediaRemoteGetNowPlayingApplicationIsPlaying(self.mediaRemoteQueue, ^(Boolean isPlaying) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion((BOOL)isPlaying);
        });
    });
}

- (BOOL)readHeadsetConnected:(BOOL *)headsetConnected {
    LATAssertMainQueue();

    AVSystemController *systemController = [self sharedAVSystemController];
    if (![systemController respondsToSelector:@selector(attributeForKey:)]) {
        return NO;
    }

    id value = [systemController attributeForKey:AVSystemController_HeadphoneJackIsConnectedAttribute];
    if (![value respondsToSelector:@selector(boolValue)]) {
        return NO;
    }

    if (headsetConnected) {
        *headsetConnected = [value boolValue];
    }
    return YES;
}

- (AVSystemController *)sharedAVSystemController {
    Class controllerClass = NSClassFromString(@"AVSystemController");
    if (![controllerClass respondsToSelector:@selector(sharedAVSystemController)]) {
        return nil;
    }
    return [(id)controllerClass sharedAVSystemController];
}

#pragma mark - Event Dispatch

- (void)sendMediaEventWithName:(NSString *)eventName {
    LATAssertMainQueue();

    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

- (void)sendHeadsetEventForConnectedState:(BOOL)headsetConnected {
    LATAssertMainQueue();

    NSString *eventName = headsetConnected ? LAEventNameHeadsetConnected : LAEventNameHeadsetDisconnected;
    [self sendMediaEventWithName:eventName];
}

@end
