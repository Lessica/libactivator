//
//  LATRuntimeStateSource.m
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATRuntimeStateSource.h"

#import "LAQueueAssertions.h"
#import "LARuntimeContext.h"
#import "LATHIDEventSender.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <notify.h>

static NSString *const LATRuntimeStateDefaultSource = @"default";
static const uint32_t LATRuntimeStateHIDPageConsumer = 0x0C;
static const uint32_t LATRuntimeStateHIDUsagePower = 0x30;
static const NSTimeInterval LATRuntimeStateScreenWakeFallbackDelay = 1.0;

@interface UIApplication (RuntimeStateSource)
- (id)_accessibilityFrontMostApplication;
@end

@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
- (NSString *)bundleIdentifier;
@end

@interface LATRuntimeStateSource ()

// Dependencies
@property(nonatomic, strong) LARuntimeContext *runtimeContext;
@property(nonatomic, strong) LATHIDEventSender *hidEventSender;

// Visibility source trackers
@property(nonatomic, strong) NSMutableSet<NSString *> *homeScreenVisibilitySources;
@property(nonatomic, strong) NSMutableSet<NSString *> *lockScreenVisibilitySources;
@property(nonatomic, strong) NSMutableSet<NSString *> *springBoardInterfaceVisibilitySources;

// Derived runtime state cache
@property(nonatomic, assign) BOOL screenBlanked;
@property(nonatomic, assign) BOOL cachedScreenOn;
@property(nonatomic, assign) BOOL cachedUILocked;
@property(nonatomic, copy) NSString *cachedEventMode;
@property(nonatomic, copy) NSString *cachedEventModeUnderneathLockScreen;
@property(nonatomic, copy, nullable) NSString *cachedDisplayIdentifier;
@property(nonatomic, copy, nullable) NSString *cachedForegroundDisplayIdentifier;
@property(nonatomic, copy, nullable) NSString *cachedLastForegroundDisplayIdentifier;
@property(nonatomic, copy, nullable) NSString *cachedPreviousForegroundDisplayIdentifier;

// Touch tracking
@property(nonatomic, strong) NSHashTable<UITouch *> *activeTouches;
@property(nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingTouchBlocks;

// Screen wake request lifecycle
@property(nonatomic, assign) BOOL wakeRequestInFlight;
@property(nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingScreenWakeCompletions;

// Lifecycle and observers
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) int screenBlankedToken;

@end

@implementation LATRuntimeStateSource

#pragma mark - Lifecycle

- (instancetype)initWithRuntimeContext:(LARuntimeContext *)runtimeContext {
    NSParameterAssert(runtimeContext);

    self = [super init];
    if (self) {
        _runtimeContext = runtimeContext;
        _homeScreenVisibilitySources = [[NSMutableSet alloc] init];
        _springBoardInterfaceVisibilitySources = [[NSMutableSet alloc] init];
        _lockScreenVisibilitySources = [[NSMutableSet alloc] init];
        _cachedScreenOn = YES;
        _cachedEventMode = LAEventModeSpringBoard;
        _cachedEventModeUnderneathLockScreen = LAEventModeSpringBoard;
        _activeTouches = [[NSHashTable alloc]
            initWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                   capacity:0];
        _pendingTouchBlocks = [[NSMutableArray alloc] init];
        _hidEventSender = [[LATHIDEventSender alloc] init];
        _pendingScreenWakeCompletions = [[NSMutableArray alloc] init];

        __weak typeof(self) weakSelf = self;
        [_runtimeContext
            setTouchActivityProvider:^BOOL {
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
    LAAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;

    [self startObservingScreenBlankedState];
    [self refreshForegroundDisplayIdentifier];
}

#pragma mark - Runtime Feed

- (void)refreshForegroundDisplayIdentifier {
    LAAssertMainQueue();
    [self refreshForegroundDisplayIdentifierOnMainThread];
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
    LAAssertMainQueue();
    return self.cachedScreenOn;
}

- (BOOL)isUILocked {
    LAAssertMainQueue();
    return self.cachedUILocked;
}

- (NSString *)displayIdentifierForCurrentApplication {
    LAAssertMainQueue();
    return [self.cachedDisplayIdentifier copy];
}

- (NSString *)displayIdentifierForPreviousApplication {
    LAAssertMainQueue();
    if (self.cachedDisplayIdentifier.length == 0) {
        return [self.cachedLastForegroundDisplayIdentifier copy];
    }
    return [self.cachedPreviousForegroundDisplayIdentifier copy];
}

- (void)startObservingScreenBlankedState {
    LAAssertMainQueue();

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
    LAAssertMainQueue();
    uint64_t blanked = 1;
    int status = notify_get_state(token, &blanked);
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Unable to read screen blanked state: %d", status);
        return;
    }
    [self noteScreenBlanked:blanked != 0];
}

- (BOOL)wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion {
    LAAssertMainQueue();

    if (!completion) {
        HBLogWarn(@"Ignoring screen wake request without completion: %@", reason ?: @"");
        return NO;
    }

    if (self.screenIsOn) {
        completion();
        return YES;
    }

    [self.pendingScreenWakeCompletions addObject:[completion copy]];
    [self requestPowerButtonWakeIfNeededForReason:reason];

    return YES;
}

- (void)noteScreenDidTurnOn {
    LAAssertMainQueue();
    if (!self.screenIsOn) {
        return;
    }
    [self completeScreenWake];
}

#pragma mark - Touch State

- (void)noteSystemTouchEvent:(UIEvent *)event {
    LAAssertMainQueue();

    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSMutableArray *blocksToRun = [NSMutableArray array];
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

    for (dispatch_block_t block in blocksToRun) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (BOOL)touchActive {
    LAAssertMainQueue();
    return self.activeTouches.count > 0;
}

- (void)performWhenTouchesEnd:(dispatch_block_t)block {
    LAAssertMainQueue();

    if (!block) {
        return;
    }

    if (self.activeTouches.count == 0) {
        dispatch_async(dispatch_get_main_queue(), block);
        return;
    }

    [self.pendingTouchBlocks addObject:[block copy]];
}

#pragma mark - Foreground Application

- (void)refreshForegroundDisplayIdentifierOnMainThread {
    LAAssertMainQueue();

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
    LAAssertMainQueue();

    NSString *identifier = [displayIdentifier isEqualToString:@"com.apple.springboard"] ? nil : displayIdentifier;
    BOOL foregroundChanged = !((identifier.length == 0 && self.cachedForegroundDisplayIdentifier.length == 0) ||
                               [identifier isEqualToString:self.cachedForegroundDisplayIdentifier]);
    if (!foregroundChanged) {
        return;
    }

    if (identifier.length > 0 && ![identifier isEqualToString:self.cachedLastForegroundDisplayIdentifier]) {
        if (self.cachedLastForegroundDisplayIdentifier.length > 0) {
            self.cachedPreviousForegroundDisplayIdentifier = [self.cachedLastForegroundDisplayIdentifier copy];
        }
        self.cachedLastForegroundDisplayIdentifier = [identifier copy];
    }
    self.cachedForegroundDisplayIdentifier = [identifier copy];
    [self recomputeCachedRuntimeState];

    [self publishCurrentState];
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
    LAAssertMainQueue();

    block();
    [self recomputeCachedRuntimeState];
    [self publishCurrentState];
}

- (void)recomputeCachedRuntimeState {
    LAAssertMainQueue();

    BOOL computedScreenOn = !self.screenBlanked;
    BOOL uiLocked = self.cachedUILocked;
    BOOL homeScreenVisible = self.homeScreenVisibilitySources.count > 0;
    BOOL springBoardInterfaceVisible = self.springBoardInterfaceVisibilitySources.count > 0;
    NSString *foregroundDisplayIdentifier = [self.cachedForegroundDisplayIdentifier copy];
    NSString *computedUnderneathMode =
        [self eventModeUnderneathLockScreenWithHomeScreenVisible:homeScreenVisible
                                     springBoardInterfaceVisible:springBoardInterfaceVisible
                                     foregroundDisplayIdentifier:foregroundDisplayIdentifier];
    NSString *computedEventMode = [self eventModeWithScreenOn:computedScreenOn
                                                     uiLocked:uiLocked
                                               underneathMode:computedUnderneathMode];
    NSString *computedDisplayIdentifier =
        [computedEventMode isEqualToString:LAEventModeApplication] ? foregroundDisplayIdentifier : nil;

    self.cachedScreenOn = computedScreenOn;
    self.cachedUILocked = uiLocked;
    self.cachedEventMode = [computedEventMode copy] ?: LAEventModeSpringBoard;
    self.cachedEventModeUnderneathLockScreen = [computedUnderneathMode copy] ?: LAEventModeSpringBoard;
    self.cachedDisplayIdentifier = [computedDisplayIdentifier copy];
    self.cachedForegroundDisplayIdentifier = [foregroundDisplayIdentifier copy];
}

- (void)publishCurrentState {
    LAAssertMainQueue();

    NSString *eventMode = [self.cachedEventMode copy];
    NSString *underneathMode = [self.cachedEventModeUnderneathLockScreen copy];
    NSString *displayIdentifier = [self.cachedDisplayIdentifier copy];
    BOOL screenOn = self.cachedScreenOn;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.runtimeContext updateEventMode:eventMode ?: LAEventModeSpringBoard
                        underneathLockScreen:underneathMode ?: LAEventModeSpringBoard
                           displayIdentifier:displayIdentifier
                                    screenOn:screenOn];
    });
}

- (void)requestPowerButtonWakeIfNeededForReason:(NSString *)reason {
    LAAssertMainQueue();

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
    LAAssertMainQueue();

    NSArray<dispatch_block_t> *completions = [self.pendingScreenWakeCompletions copy];
    [self.pendingScreenWakeCompletions removeAllObjects];
    [self resetWakeRequest];

    for (dispatch_block_t completion in completions) {
        completion();
    }
}

- (void)resetWakeRequest {
    LAAssertMainQueue();

    self.wakeRequestInFlight = NO;
}

@end
