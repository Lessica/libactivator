//
//  LATRuntimeStateSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATRuntimeStateSource.h"

#import "LAActivator+Private.h"
#import "LATHIDEventSender.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <notify.h>

#define kLATRuntimeStateSourceMainQueueReason @"LATRuntimeStateSource must only be used on the main thread"

static NSString *const LATRuntimeStateDefaultSource = @"default";
static const uint32_t LATRuntimeStateHIDPageConsumer = 0x0C;
static const uint32_t LATRuntimeStateHIDUsagePower = 0x30;
static const NSTimeInterval LATRuntimeStateScreenWakeFallbackDelay = 1.0;

@interface UIApplication (LATRuntimeStateSourceSpringBoard)
- (id)_accessibilityFrontMostApplication;
@end

@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
- (NSString *)bundleIdentifier;
@end

@interface LATRuntimeStateSource ()
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) NSMutableSet *homeScreenVisibilitySources;
@property(nonatomic, strong) NSMutableSet *springBoardInterfaceVisibilitySources;
@property(nonatomic, strong) NSMutableSet *lockScreenVisibilitySources;
@property(nonatomic, assign) BOOL screenBlanked;
@property(nonatomic, assign) BOOL cachedScreenOn;
@property(nonatomic, assign) BOOL cachedUILocked;
@property(nonatomic, assign) NSUInteger stateGeneration;
@property(nonatomic, strong) dispatch_queue_t stateQueue;
@property(nonatomic, copy) NSString *cachedEventMode;
@property(nonatomic, copy) NSString *cachedEventModeUnderneathLockScreen;
@property(nonatomic, copy, nullable) NSString *cachedDisplayIdentifier;
@property(nonatomic, copy, nullable) NSString *cachedForegroundDisplayIdentifier;
@property(nonatomic, strong) dispatch_queue_t touchQueue;
@property(nonatomic, strong) NSHashTable *activeTouches;
@property(nonatomic, strong) NSMutableArray *pendingTouchBlocks;
@property(nonatomic, strong) LATHIDEventSender *hidEventSender;
@property(nonatomic, assign) BOOL wakeRequestInFlight;
@property(nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingScreenWakeCompletions;
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) int screenBlankedToken;
@end

@implementation LATRuntimeStateSource

#pragma mark - Lifecycle

- (instancetype)initWithActivator:(LAActivator *)activator {
    self = [super init];
    if (self) {
        _activator = activator;
        _homeScreenVisibilitySources = [[NSMutableSet alloc] init];
        _springBoardInterfaceVisibilitySources = [[NSMutableSet alloc] init];
        _lockScreenVisibilitySources = [[NSMutableSet alloc] init];
        _stateQueue = dispatch_queue_create("libactivator.tweak.runtime-state",
                                            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _cachedScreenOn = YES;
        _cachedEventMode = LAEventModeSpringBoard;
        _cachedEventModeUnderneathLockScreen = LAEventModeSpringBoard;
        _touchQueue =
            dispatch_queue_create("libactivator.tweak.touch-activity", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _activeTouches = [[NSHashTable alloc]
            initWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                   capacity:0];
        _pendingTouchBlocks = [[NSMutableArray alloc] init];
        _hidEventSender = [[LATHIDEventSender alloc] init];
        _pendingScreenWakeCompletions = [[NSMutableArray alloc] init];

        __weak typeof(self) weakSelf = self;
        [activator
            la_setSystemTouchActivityProvider:^BOOL {
                return [weakSelf touchActive];
            }
            touchesEndedPerformer:^(dispatch_block_t block) {
                [weakSelf performWhenTouchesEnd:block];
            }];
        [self publishCurrentState];
    }
    return self;
}

- (void)start {
    NSAssert(NSThread.isMainThread, kLATRuntimeStateSourceMainQueueReason);
    if (self.started) {
        return;
    }
    self.started = YES;

    [self startObservingScreenBlankedState];
    [self refreshForegroundDisplayIdentifier];
}

#pragma mark - Runtime Feed

- (void)refreshForegroundDisplayIdentifier {
    dispatch_block_t refreshBlock = ^{
        [self refreshForegroundDisplayIdentifierOnMainThread];
    };
    if (NSThread.isMainThread) {
        refreshBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), refreshBlock);
    }
}

- (void)noteHomeScreenVisible:(BOOL)visible source:(NSString *)source {
    [self updateStateWithBlock:^{
        [self updateVisibilitySet:self->_homeScreenVisibilitySources visible:visible source:source];
    }];
}

- (void)noteSpringBoardInterfaceVisible:(BOOL)visible source:(NSString *)source {
    [self updateStateWithBlock:^{
        [self updateVisibilitySet:self->_springBoardInterfaceVisibilitySources visible:visible source:source];
    }];
}

- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source {
    [self updateStateWithBlock:^{
        [self updateVisibilitySet:self->_lockScreenVisibilitySources visible:visible source:source];
    }];
}

- (void)noteUILocked:(BOOL)uiLocked {
    [self updateStateWithBlock:^{
        self->_cachedUILocked = uiLocked;
    }];
}

- (void)noteScreenBlanked:(BOOL)blanked {
    __block BOOL screenDidTurnOn = NO;
    [self updateStateWithBlock:^{
        screenDidTurnOn = self->_screenBlanked && !blanked;
        self->_screenBlanked = blanked;
    }];
    if (screenDidTurnOn) {
        [self noteScreenDidTurnOn];
    }
}

#pragma mark - Screen State

- (BOOL)screenIsOn {
    __block BOOL screenOn = YES;
    dispatch_sync(self.stateQueue, ^{
        screenOn = self.cachedScreenOn;
    });
    return screenOn;
}

- (void)startObservingScreenBlankedState {
    NSAssert(NSThread.isMainThread, kLATRuntimeStateSourceMainQueueReason);

    __weak typeof(self) weakSelf = self;
    int token = 0;
    int status = notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &token, dispatch_get_main_queue(),
                                          ^(int deliveredToken) {
                                              __strong typeof(weakSelf) strongSelf = weakSelf;
                                              [strongSelf handleScreenBlankedNotificationWithToken:deliveredToken];
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogWarn(@"Unable to observe screen blanked state: %d", status);
        return;
    }

    self.screenBlankedToken = token;
    [self handleScreenBlankedNotificationWithToken:token];
}

- (void)handleScreenBlankedNotificationWithToken:(int)token {
    NSAssert(NSThread.isMainThread, kLATRuntimeStateSourceMainQueueReason);
    uint64_t blanked = 1;
    int status = notify_get_state(token, &blanked);
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Unable to read screen blanked state: %d", status);
        return;
    }
    [self noteScreenBlanked:blanked != 0];
}

- (BOOL)wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion {
    if (!completion) {
        HBLogWarn(@"Ignoring screen wake request without completion: %@", reason ?: @"");
        return NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.screenIsOn) {
            completion();
            return;
        }

        [self.pendingScreenWakeCompletions addObject:[completion copy]];
        [self requestPowerButtonWakeIfNeededForReason:reason];
    });

    return YES;
}

- (void)noteScreenDidTurnOn {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.screenIsOn) {
            return;
        }
        [self completeScreenWake];
    });
}

#pragma mark - Touch State

- (void)noteSystemTouchEvent:(UIEvent *)event {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSMutableArray *blocksToRun = [NSMutableArray array];
    dispatch_sync(self.touchQueue, ^{
        for (UITouch *touch in event.allTouches) {
            if (![touch isKindOfClass:UITouch.class]) {
                continue;
            }
            if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
                [self.activeTouches removeObject:touch];
            } else {
                [self.activeTouches addObject:touch];
            }
        }
        if (self.activeTouches.count == 0 && self.pendingTouchBlocks.count > 0) {
            [blocksToRun addObjectsFromArray:self.pendingTouchBlocks];
            [self.pendingTouchBlocks removeAllObjects];
        }
    });

    for (dispatch_block_t block in blocksToRun) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (BOOL)touchActive {
    __block BOOL touchActive = NO;
    dispatch_sync(self.touchQueue, ^{
        touchActive = self.activeTouches.count > 0;
    });
    return touchActive;
}

- (void)performWhenTouchesEnd:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    __block BOOL shouldRunNow = NO;
    dispatch_sync(self.touchQueue, ^{
        if (self.activeTouches.count == 0) {
            shouldRunNow = YES;
        } else {
            [self.pendingTouchBlocks addObject:[block copy]];
        }
    });
    if (shouldRunNow) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

#pragma mark - Foreground Application

- (void)refreshForegroundDisplayIdentifierOnMainThread {
    NSAssert(NSThread.isMainThread, kLATRuntimeStateSourceMainQueueReason);

    UIApplication *application = UIApplication.sharedApplication;
    if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
        [self noteForegroundDisplayIdentifier:nil];
        return;
    }

    SBApplication *frontMostApplication = (SBApplication *)[application _accessibilityFrontMostApplication];
    NSString *displayIdentifier = nil;
    if ([frontMostApplication respondsToSelector:@selector(displayIdentifier)]) {
        displayIdentifier = [frontMostApplication displayIdentifier];
    }
    if (displayIdentifier.length == 0 && [frontMostApplication respondsToSelector:@selector(bundleIdentifier)]) {
        displayIdentifier = [frontMostApplication bundleIdentifier];
    }
    if ([displayIdentifier isEqualToString:@"com.apple.springboard"]) {
        displayIdentifier = nil;
    }

    [self noteForegroundDisplayIdentifier:displayIdentifier];
}

- (void)noteForegroundDisplayIdentifier:(NSString *)displayIdentifier {
    [self updateStateWithBlock:^{
        NSString *identifier = [displayIdentifier isEqualToString:@"com.apple.springboard"] ? nil : displayIdentifier;
        self->_cachedForegroundDisplayIdentifier = [identifier copy];
    }];
}

#pragma mark - Private

- (NSString *)eventModeWithScreenOn:(BOOL)screenOn uiLocked:(BOOL)uiLocked underneathMode:(NSString *)underneathMode {
    if (!screenOn || uiLocked) {
        return LAEventModeLockScreen;
    }
    return underneathMode ?: LAEventModeSpringBoard;
}

- (NSString *)eventModeUnderneathLockScreenWithHomeScreenVisible:(BOOL)homeScreenVisible
                                     springBoardInterfaceVisible:(BOOL)springBoardInterfaceVisible
                                     foregroundDisplayIdentifier:(NSString *)foregroundDisplayIdentifier {
    if (homeScreenVisible || springBoardInterfaceVisible) {
        return LAEventModeSpringBoard;
    }
    if (foregroundDisplayIdentifier.length > 0) {
        return LAEventModeApplication;
    }
    return LAEventModeSpringBoard;
}

- (void)updateVisibilitySet:(NSMutableSet *)visibilitySet visible:(BOOL)visible source:(NSString *)source {
    NSString *visibilitySource = source.length > 0 ? source : LATRuntimeStateDefaultSource;
    if (visible) {
        [visibilitySet addObject:visibilitySource];
    } else {
        [visibilitySet removeObject:visibilitySource];
    }
}

- (void)updateStateWithBlock:(void (^)(void))block {
    __block NSUInteger generation = 0;
    __block BOOL screenOn = YES;
    __block BOOL uiLocked = NO;
    __block BOOL homeScreenVisible = NO;
    __block BOOL springBoardInterfaceVisible = NO;
    __block NSString *foregroundDisplayIdentifier = nil;
    dispatch_sync(self.stateQueue, ^{
        block();
        self->_stateGeneration++;
        generation = self->_stateGeneration;
        screenOn = !self->_screenBlanked;
        uiLocked = self->_cachedUILocked;
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        springBoardInterfaceVisible = self->_springBoardInterfaceVisibilitySources.count > 0;
        foregroundDisplayIdentifier = [self->_cachedForegroundDisplayIdentifier copy];
    });

    NSString *underneathMode = [self eventModeUnderneathLockScreenWithHomeScreenVisible:homeScreenVisible
                                                            springBoardInterfaceVisible:springBoardInterfaceVisible
                                                            foregroundDisplayIdentifier:foregroundDisplayIdentifier];
    NSString *eventMode = [self eventModeWithScreenOn:screenOn uiLocked:uiLocked underneathMode:underneathMode];
    NSString *displayIdentifier =
        [eventMode isEqualToString:LAEventModeApplication] ? foregroundDisplayIdentifier : nil;
    dispatch_sync(self.stateQueue, ^{
        if (generation != self->_stateGeneration) {
            return;
        }

        self->_cachedScreenOn = screenOn;
        self->_cachedUILocked = uiLocked;
        self->_cachedEventMode = [eventMode copy] ?: LAEventModeSpringBoard;
        self->_cachedEventModeUnderneathLockScreen = [underneathMode copy] ?: LAEventModeSpringBoard;
        self->_cachedDisplayIdentifier = [displayIdentifier copy];
        self->_cachedForegroundDisplayIdentifier = [foregroundDisplayIdentifier copy];
    });

    [self publishCurrentState];
}

- (void)publishCurrentState {
    __block NSString *eventMode = nil;
    __block NSString *underneathMode = nil;
    __block NSString *displayIdentifier = nil;
    __block BOOL screenOn = YES;
    dispatch_sync(self.stateQueue, ^{
        eventMode = [self->_cachedEventMode copy];
        underneathMode = [self->_cachedEventModeUnderneathLockScreen copy];
        displayIdentifier = [self->_cachedDisplayIdentifier copy];
        screenOn = self->_cachedScreenOn;
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activator la_updateRuntimeEventMode:eventMode ?: LAEventModeSpringBoard
                             underneathLockScreen:underneathMode ?: LAEventModeSpringBoard
                                 displayIdentifier:displayIdentifier
                                          screenOn:screenOn];
    });
}

- (void)requestPowerButtonWakeIfNeededForReason:(NSString *)reason {
    if (self.wakeRequestInFlight) {
        return;
    }

    self.wakeRequestInFlight = YES;
    if (![self.hidEventSender sendKeyboardUsagePage:LATRuntimeStateHIDPageConsumer
                                             usage:LATRuntimeStateHIDUsagePower
                                            reason:reason]) {
        [self resetWakeRequest];
        [self.pendingScreenWakeCompletions removeAllObjects];
        HBLogWarn(@"Unable to press power button for screen wake: %@", reason ?: @"");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATRuntimeStateScreenWakeFallbackDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       if (!self.wakeRequestInFlight) {
                           return;
                       }
                       if (!self.screenIsOn) {
                           HBLogWarn(@"Screen did not turn on before wake request timed out");
                           [self resetWakeRequest];
                           [self.pendingScreenWakeCompletions removeAllObjects];
                           return;
                       }

                       [self completeScreenWake];
                   });
}

- (void)completeScreenWake {
    NSArray<dispatch_block_t> *completions = [self.pendingScreenWakeCompletions copy];
    [self.pendingScreenWakeCompletions removeAllObjects];
    [self resetWakeRequest];

    for (dispatch_block_t completion in completions) {
        completion();
    }
}

- (void)resetWakeRequest {
    self.wakeRequestInFlight = NO;
}

@end
