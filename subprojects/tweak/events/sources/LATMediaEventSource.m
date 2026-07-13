//
//  LATMediaEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMediaEventSource.h"

#import "LAQueueAssertions.h"
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

extern void MRMediaRemoteGetNowPlayingApplicationDisplayID(dispatch_queue_t queue,
                                                           void (^completion)(CFStringRef displayID))
    __attribute__((weak_import));
extern CFStringRef SBSCopyDisplayIdentifierForProcessID(pid_t PID) __attribute__((weak_import));

@interface AVSystemController : NSObject
+ (instancetype)sharedAVSystemController;
- (id)attributeForKey:(AVSystemControllerKey)attributeKey;
@end

@interface LATMediaEventSource ()

// Dependencies
@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;

// Lifecycle
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

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

// MediaRemote lifecycle
@property(nonatomic, assign) NSUInteger identityRequestGeneration;
@property(nonatomic, assign) BOOL wantsNowPlayingNotifications;
@property(nonatomic, assign) BOOL wantsRouteChangeNotifications;

@end

@implementation LATMediaEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (NSString *)eventSourceIdentifier {
    return @"media";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithArray:@[
        LAEventNameHeadsetConnected,
        LAEventNameHeadsetDisconnected,
        LAEventNameNowPlayingInfoChanged,
        LAEventNameNowPlayingPaused,
        LAEventNameNowPlayingPlaying,
    ]];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0);
        _mediaRemoteQueue = dispatch_queue_create("libactivator.mediaremote", attr);
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.started || self.isInvalidated) {
        return;
    }
    self.started = YES;

    [self refreshKnownHeadsetStateWithoutSendingEvent];
    [self startMediaRemoteRouteMonitoring];
    [self startMediaRemoteNowPlayingMonitoring];
    [self startAVSystemControllerRouteMonitoring];
}

- (void)dealloc {
    [self removeObservers];
    [self stopRequestingMediaRemoteNotifications];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    self.identityRequestGeneration += 1;
    [self removeObservers];
    [self stopRequestingMediaRemoteNotifications];
    self.hasKnownHeadsetState = NO;
    self.headsetConnected = NO;
    self.hasKnownNowPlayingPlaybackState = NO;
    self.nowPlayingApplicationPlaying = NO;
}

- (void)removeObservers {
    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    if (_routeStatusObserver) {
        [notificationCenter removeObserver:_routeStatusObserver];
        _routeStatusObserver = nil;
    }
    if (_pickableRoutesObserver) {
        [notificationCenter removeObserver:_pickableRoutesObserver];
        _pickableRoutesObserver = nil;
    }
    if (_nowPlayingInfoObserver) {
        [notificationCenter removeObserver:_nowPlayingInfoObserver];
        _nowPlayingInfoObserver = nil;
    }
    if (_nowPlayingApplicationIsPlayingObserver) {
        [notificationCenter removeObserver:_nowPlayingApplicationIsPlayingObserver];
        _nowPlayingApplicationIsPlayingObserver = nil;
    }
    if (_activeAudioRouteObserver) {
        [notificationCenter removeObserver:_activeAudioRouteObserver];
        _activeAudioRouteObserver = nil;
    }
    if (_systemPickableRoutesObserver) {
        [notificationCenter removeObserver:_systemPickableRoutesObserver];
        _systemPickableRoutesObserver = nil;
    }
    if (_headphoneStateObserver) {
        [notificationCenter removeObserver:_headphoneStateObserver];
        _headphoneStateObserver = nil;
    }
}

#pragma mark - Now Playing Identity

- (BOOL)requestNowPlayingApplicationDisplayIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    LAAssertMainQueue();
    if (!self.started || !completion) {
        return NO;
    }

    MRMediaRemoteSetWantsNowPlayingNotifications(true);
    self.wantsNowPlayingNotifications = YES;
    NSUInteger generation = self.identityRequestGeneration;

    if (MRMediaRemoteGetNowPlayingApplicationDisplayID) {
        [self requestMediaRemoteDisplayIdentifierWithGeneration:generation completion:completion];
        return YES;
    }

    if (SBSCopyDisplayIdentifierForProcessID) {
        [self requestMediaRemoteProcessIdentifierWithGeneration:generation completion:completion];
        return YES;
    }

    HBLogError(@"Unable to request now-playing application identity because required APIs are unavailable");
    return NO;
}

- (void)requestMediaRemoteDisplayIdentifierWithGeneration:(NSUInteger)generation
                                               completion:
                                                   (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    __weak typeof(self) weakSelf = self;
    MRMediaRemoteGetNowPlayingApplicationDisplayID(self.mediaRemoteQueue, ^(CFStringRef displayID) {
        NSString *identifier = [(__bridge NSString *)displayID copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf.started || generation != strongSelf.identityRequestGeneration) {
                return;
            }
            if (identifier.length > 0) {
                completion(identifier);
                return;
            }

            HBLogWarn(@"MediaRemote returned no now-playing application display identifier");
            if (SBSCopyDisplayIdentifierForProcessID) {
                [strongSelf requestMediaRemoteProcessIdentifierWithGeneration:generation completion:completion];
                return;
            }
            completion(nil);
        });
    });
}

- (void)requestMediaRemoteProcessIdentifierWithGeneration:(NSUInteger)generation
                                               completion:
                                                   (LATNowPlayingApplicationDisplayIdentifierCompletion)completion {
    __weak typeof(self) weakSelf = self;
    MRMediaRemoteGetNowPlayingApplicationPID(self.mediaRemoteQueue, ^(int PID) {
        NSString *identifier = nil;
        if (PID <= 0) {
            HBLogWarn(@"MediaRemote returned no now-playing application process identifier");
        } else {
            CFStringRef displayID = SBSCopyDisplayIdentifierForProcessID((pid_t)PID);
            identifier = displayID ? CFBridgingRelease(displayID) : nil;
            if (identifier.length == 0) {
                HBLogError(@"Unable to resolve now-playing application display identifier for process %d", PID);
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf.started || generation != strongSelf.identityRequestGeneration) {
                return;
            }
            completion(identifier);
        });
    });
}

#pragma mark - Monitoring

- (void)startMediaRemoteRouteMonitoring {
    LAAssertMainQueue();

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
    self.wantsRouteChangeNotifications = YES;
}

- (void)startMediaRemoteNowPlayingMonitoring {
    LAAssertMainQueue();

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
    self.wantsNowPlayingNotifications = YES;
    [self refreshKnownNowPlayingPlaybackStateWithoutSendingEvent];
}

- (void)stopRequestingMediaRemoteNotifications {
    if (_wantsRouteChangeNotifications) {
        MRMediaRemoteSetWantsRouteChangeNotifications(false);
        _wantsRouteChangeNotifications = NO;
    }
    if (_wantsNowPlayingNotifications) {
        MRMediaRemoteSetWantsNowPlayingNotifications(false);
        _wantsNowPlayingNotifications = NO;
    }
}

- (void)startAVSystemControllerRouteMonitoring {
    LAAssertMainQueue();

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
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    HBLogInfo(@"MediaRemote route notification for media event source: name=%@ object=%@ userInfo=%@",
              notification.name ?: @"", notification.object ?: @"", notification.userInfo ?: @{});
    [self handlePotentialHeadsetStateChange];
}

- (void)handleNowPlayingInfoDidChangeNotification {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    MRMediaRemoteGetNowPlayingInfo(self.mediaRemoteQueue, ^(__unused CFDictionaryRef information) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf.started) {
                return;
            }
            [strongSelf sendMediaEventWithName:LAEventNameNowPlayingInfoChanged];
        });
    });
}

- (void)handleNowPlayingApplicationIsPlayingDidChangeNotification:(NSNotification *)notification {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

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
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    if (!self.hasKnownNowPlayingPlaybackState) {
        self.hasKnownNowPlayingPlaybackState = YES;
        self.nowPlayingApplicationPlaying = isPlaying;
        return;
    }

    if (self.nowPlayingApplicationPlaying == isPlaying) {
        return;
    }

    self.nowPlayingApplicationPlaying = isPlaying;
    [self sendMediaEventWithName:isPlaying ? LAEventNameNowPlayingPlaying : LAEventNameNowPlayingPaused];
}

- (void)handlePotentialHeadsetStateChange {
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

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
    LAAssertMainQueue();

    BOOL headsetConnected = NO;
    if (![self readHeadsetConnected:&headsetConnected]) {
        return;
    }
    self.hasKnownHeadsetState = YES;
    self.headsetConnected = headsetConnected;
}

- (void)refreshKnownNowPlayingPlaybackStateWithoutSendingEvent {
    LAAssertMainQueue();

    [self requestNowPlayingPlaybackStateWithCompletion:^(BOOL isPlaying) {
        if (!self.started || self.hasKnownNowPlayingPlaybackState) {
            return;
        }
        self.hasKnownNowPlayingPlaybackState = YES;
        self.nowPlayingApplicationPlaying = isPlaying;
    }];
}

- (BOOL)getKnownNowPlayingApplicationPlaying:(BOOL *)isPlaying {
    LAAssertMainQueue();
    if (!self.started || !self.hasKnownNowPlayingPlaybackState) {
        return NO;
    }
    if (isPlaying) {
        *isPlaying = self.nowPlayingApplicationPlaying;
    }
    return YES;
}

- (void)requestNowPlayingPlaybackStateWithCompletion:(void (^)(BOOL isPlaying))completion {
    LAAssertMainQueue();
    NSParameterAssert(completion);

    MRMediaRemoteGetNowPlayingApplicationIsPlaying(self.mediaRemoteQueue, ^(Boolean isPlaying) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion((BOOL)isPlaying);
        });
    });
}

- (BOOL)readHeadsetConnected:(BOOL *)headsetConnected {
    LAAssertMainQueue();

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
    LAAssertMainQueue();
    if (!self.started) {
        return;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
}

- (void)sendHeadsetEventForConnectedState:(BOOL)headsetConnected {
    LAAssertMainQueue();

    NSString *eventName = headsetConnected ? LAEventNameHeadsetConnected : LAEventNameHeadsetDisconnected;
    [self sendMediaEventWithName:eventName];
}

@end
