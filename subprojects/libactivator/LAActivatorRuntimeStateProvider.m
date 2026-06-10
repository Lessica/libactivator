//
//  LAActivatorRuntimeStateProvider.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorRuntimeStateProvider.h"
#import "LAActivatorUnlockService.h"

#import <UIKit/UIKit.h>

static NSString *const LAActivatorRuntimeStateDefaultSource = @"default";

@interface UIApplication (LAActivatorSpringBoard)
- (id)_accessibilityFrontMostApplication;
@end

@protocol LAActivatorSpringBoardApplication <NSObject>
@optional
- (NSString *)bundleIdentifier;
- (NSString *)displayIdentifier;
@end

@interface LAActivatorRuntimeStateProvider ()
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
@property(nonatomic, copy, nullable) void (^eventModeChangeHandler)(NSString *eventMode);
@property(nonatomic, strong) LAActivatorUnlockService *unlockService;
@end

@implementation LAActivatorRuntimeStateProvider

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _homeScreenVisibilitySources = [[NSMutableSet alloc] init];
        _springBoardInterfaceVisibilitySources = [[NSMutableSet alloc] init];
        _lockScreenVisibilitySources = [[NSMutableSet alloc] init];
        _stateQueue = dispatch_queue_create("libactivator.runtime-state", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _unlockService = [[LAActivatorUnlockService alloc] init];
        _cachedScreenOn = YES;
        _cachedEventMode = LAEventModeSpringBoard;
        _cachedEventModeUnderneathLockScreen = LAEventModeSpringBoard;
    }
    return self;
}

#pragma mark - Updates

- (void)noteHomeScreenVisible:(BOOL)visible {
    if (visible) {
        [self noteHomeScreenVisible:YES source:LAActivatorRuntimeStateDefaultSource];
        return;
    }
    [self updateStateWithBlock:^{
        [self->_homeScreenVisibilitySources removeAllObjects];
    }];
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

- (void)noteLockScreenVisible:(BOOL)visible {
    if (visible) {
        [self noteLockScreenVisible:YES source:LAActivatorRuntimeStateDefaultSource];
        return;
    }
    [self updateStateWithBlock:^{
        [self->_lockScreenVisibilitySources removeAllObjects];
    }];
}

- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source {
    [self updateStateWithBlock:^{
        [self updateVisibilitySet:self->_lockScreenVisibilitySources visible:visible source:source];
    }];
}

- (void)noteScreenBlanked:(BOOL)blanked {
    [self updateStateWithBlock:^{
        self->_screenBlanked = blanked;
    }];
}

- (void)noteRuntimeStateMayHaveChanged {
    [self updateStateWithBlock:^{
    }];
}

- (void)setEventModeChangeHandler:(void (^)(NSString *eventMode))handler {
    dispatch_sync(_stateQueue, ^{
        self->_eventModeChangeHandler = [handler copy];
    });
}

#pragma mark - State

- (NSString *)currentEventMode {
    __block NSString *eventMode = nil;
    dispatch_sync(_stateQueue, ^{
        eventMode = [self->_cachedEventMode copy];
    });
    return eventMode ?: LAEventModeSpringBoard;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    __block NSString *eventMode = nil;
    dispatch_sync(_stateQueue, ^{
        eventMode = [self->_cachedEventModeUnderneathLockScreen copy];
    });
    return eventMode ?: LAEventModeSpringBoard;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return [_unlockService supportsUnlockingDeviceToSendEvents];
}

- (NSString *)displayIdentifierForCurrentApplication {
    __block NSString *displayIdentifier = nil;
    dispatch_sync(_stateQueue, ^{
        displayIdentifier = [self->_cachedDisplayIdentifier copy];
    });
    return displayIdentifier;
}

#if LA_TESTING
- (NSDictionary *)testingDebugDictionary {
    __block NSArray *homeSources = nil;
    __block NSArray *springBoardInterfaceSources = nil;
    __block NSArray *lockSources = nil;
    __block BOOL screenOn = YES;
    __block BOOL uiLocked = NO;
    __block NSString *frontMost = nil;
    __block NSString *mode = nil;
    __block NSString *underneathMode = nil;
    __block NSString *displayIdentifier = nil;
    dispatch_sync(_stateQueue, ^{
        homeSources = [[self->_homeScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        springBoardInterfaceSources =
            [[self->_springBoardInterfaceVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        lockSources = [[self->_lockScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        screenOn = self->_cachedScreenOn;
        uiLocked = self->_cachedUILocked;
        frontMost = [self->_cachedForegroundDisplayIdentifier copy];
        mode = [self->_cachedEventMode copy];
        underneathMode = [self->_cachedEventModeUnderneathLockScreen copy];
        displayIdentifier = [self->_cachedDisplayIdentifier copy];
    });

    BOOL springBoardInterfaceVisible = homeSources.count > 0 || springBoardInterfaceSources.count > 0;
    return @{
        @"Mode" : mode ?: @"",
        @"UnderneathMode" : underneathMode ?: @"",
        @"DisplayIdentifier" : displayIdentifier ?: @"",
        @"HomeSources" : homeSources ?: @[],
        @"SpringBoardInterfaceSources" : springBoardInterfaceSources ?: @[],
        @"LockSources" : lockSources ?: @[],
        @"ScreenOn" : @(screenOn),
        @"LockScreenVisible" : @(lockSources.count > 0),
        @"SpringBoardInterfaceVisible" : @(springBoardInterfaceVisible),
        @"InLockScreen" : @(!screenOn || uiLocked),
        @"UILocked" : @(uiLocked),
        @"FrontMost" : frontMost ?: @"",
    };
}
#endif

#pragma mark - Private

- (NSString *)foregroundDisplayIdentifierIgnoringLockState {
    __block NSString *displayIdentifier = nil;
    dispatch_block_t block = ^{
        UIApplication *application = [UIApplication sharedApplication];
        if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
            return;
        }

        id<LAActivatorSpringBoardApplication> frontMostApplication = [application _accessibilityFrontMostApplication];
        displayIdentifier = [self displayIdentifierForApplication:frontMostApplication];
    };

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }

    if ([displayIdentifier isEqualToString:@"com.apple.springboard"]) {
        return nil;
    }
    return displayIdentifier;
}

- (NSString *)displayIdentifierForApplication:(id<LAActivatorSpringBoardApplication>)application {
    if ([application respondsToSelector:@selector(displayIdentifier)]) {
        NSString *displayIdentifier = [application displayIdentifier];
        if ([displayIdentifier isKindOfClass:NSString.class] && displayIdentifier.length > 0) {
            return displayIdentifier;
        }
    }
    if ([application respondsToSelector:@selector(bundleIdentifier)]) {
        NSString *bundleIdentifier = [application bundleIdentifier];
        if ([bundleIdentifier isKindOfClass:NSString.class] && bundleIdentifier.length > 0) {
            return bundleIdentifier;
        }
    }
    return nil;
}

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
    NSString *visibilitySource = source.length > 0 ? source : LAActivatorRuntimeStateDefaultSource;
    if (visible) {
        [visibilitySet addObject:visibilitySource];
    } else {
        [visibilitySet removeObject:visibilitySource];
    }
}

- (void)updateStateWithBlock:(void (^)(void))block {
    __block NSString *previousMode = nil;
    __block NSUInteger generation = 0;
    __block BOOL screenOn = YES;
    __block BOOL homeScreenVisible = NO;
    __block BOOL springBoardInterfaceVisible = NO;
    dispatch_sync(_stateQueue, ^{
        previousMode = [self->_cachedEventMode copy];
        block();
        self->_stateGeneration++;
        generation = self->_stateGeneration;
        screenOn = !self->_screenBlanked;
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        springBoardInterfaceVisible = self->_springBoardInterfaceVisibilitySources.count > 0;
    });

    BOOL uiLocked = [_unlockService isUILocked];
    NSString *foregroundDisplayIdentifier = [self foregroundDisplayIdentifierIgnoringLockState];
    NSString *underneathMode = [self eventModeUnderneathLockScreenWithHomeScreenVisible:homeScreenVisible
                                                            springBoardInterfaceVisible:springBoardInterfaceVisible
                                                            foregroundDisplayIdentifier:foregroundDisplayIdentifier];
    NSString *eventMode = [self eventModeWithScreenOn:screenOn uiLocked:uiLocked underneathMode:underneathMode];
    NSString *displayIdentifier =
        [eventMode isEqualToString:LAEventModeApplication] ? foregroundDisplayIdentifier : nil;
    __block void (^handler)(NSString *eventMode) = nil;
    dispatch_sync(_stateQueue, ^{
        if (generation != self->_stateGeneration) {
            return;
        }

        self->_cachedScreenOn = screenOn;
        self->_cachedUILocked = uiLocked;
        self->_cachedEventMode = [eventMode copy] ?: LAEventModeSpringBoard;
        self->_cachedEventModeUnderneathLockScreen = [underneathMode copy] ?: LAEventModeSpringBoard;
        self->_cachedDisplayIdentifier = [displayIdentifier copy];
        self->_cachedForegroundDisplayIdentifier = [foregroundDisplayIdentifier copy];

        if (eventMode.length > 0 && ![eventMode isEqualToString:previousMode]) {
            handler = [self->_eventModeChangeHandler copy];
        }
    });
    if (eventMode.length == 0 || [eventMode isEqualToString:previousMode] || !handler) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(eventMode);
    });
}

@end
