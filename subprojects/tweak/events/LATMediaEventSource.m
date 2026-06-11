//
//  LATMediaEventSource.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATMediaEventSource.h"

#import "LAActivator+Private.h"
#import "MediaRemote+Private.h"

#import <HBLog.h>

#define kLATMediaEventSourceMainQueueReason @"LATMediaEventSource must only be used on the main thread"

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
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) BOOL hasKnownHeadsetState;
@property(nonatomic, assign, getter=isHeadsetConnected) BOOL headsetConnected;
@property(nonatomic, strong) id routeStatusObserver;
@property(nonatomic, strong) id pickableRoutesObserver;
@property(nonatomic, strong) id activeAudioRouteObserver;
@property(nonatomic, strong) id systemPickableRoutesObserver;
@property(nonatomic, strong) id headphoneStateObserver;
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
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);
    if (self.started) {
        return;
    }
    self.started = YES;

    [self refreshKnownHeadsetStateWithoutSendingEvent];
    [self startMediaRemoteRouteMonitoring];
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
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);
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
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

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

- (void)startAVSystemControllerRouteMonitoring {
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

    HBLogInfo(@"MediaRemote route notification for media event source: name=%@ object=%@ userInfo=%@",
              notification.name ?: @"", notification.object ?: @"", notification.userInfo ?: @{});
    [self handlePotentialHeadsetStateChange];
}

- (void)handlePotentialHeadsetStateChange {
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

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
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

    BOOL headsetConnected = NO;
    if (![self readHeadsetConnected:&headsetConnected]) {
        return;
    }
    self.hasKnownHeadsetState = YES;
    self.headsetConnected = headsetConnected;
}

- (BOOL)readHeadsetConnected:(BOOL *)headsetConnected {
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

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

- (void)sendHeadsetEventForConnectedState:(BOOL)headsetConnected {
    NSAssert(NSThread.isMainThread, kLATMediaEventSourceMainQueueReason);

    NSString *eventName = headsetConnected ? LAEventNameHeadsetConnected : LAEventNameHeadsetDisconnected;
    NSString *eventMode = LASharedActivator.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
    [LASharedActivator sendEventToListener:event];
}

@end
