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

@interface UIApplication (LAActivatorSpringBoard)
- (id)_accessibilityFrontMostApplication;
@end

@protocol LAActivatorSpringBoardApplication <NSObject>
@optional
- (NSString *)bundleIdentifier;
- (NSString *)displayIdentifier;
@end

@interface LAActivatorRuntimeStateProvider ()
- (NSString *)foregroundDisplayIdentifierIgnoringLockState;
- (NSString *)displayIdentifierForApplication:(id<LAActivatorSpringBoardApplication>)application;
- (BOOL)strongHomeScreenVisible;
- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
                        strongHomeScreenVisible:(BOOL)strongHomeScreenVisible
                           lockScreenVisible:(BOOL)lockScreenVisible
                               screenBlanked:(BOOL)screenBlanked;
- (void)updateStateWithBlock:(void (^)(void))block;
@end

@implementation LAActivatorRuntimeStateProvider {
    NSMutableSet *_homeScreenVisibilitySources;
    NSMutableSet *_lockScreenVisibilitySources;
    BOOL _screenBlanked;
    dispatch_queue_t _stateQueue;
    NSString *_lastEventMode;
    void (^_eventModeChangeHandler)(NSString *eventMode);
    LAActivatorUnlockService *_unlockService;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _homeScreenVisibilitySources = [[NSMutableSet alloc] init];
        _lockScreenVisibilitySources = [[NSMutableSet alloc] init];
        _stateQueue = dispatch_queue_create("libactivator.runtime-state", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _unlockService = [[LAActivatorUnlockService alloc] init];
        _lastEventMode = LAEventModeSpringBoard;
    }
    return self;
}

#pragma mark - Updates

- (void)noteHomeScreenVisible:(BOOL)visible {
    if (visible) {
        [self noteHomeScreenVisible:YES source:@"default"];
        return;
    }
    [self updateStateWithBlock:^{
        [self->_homeScreenVisibilitySources removeAllObjects];
    }];
}

- (void)noteHomeScreenVisible:(BOOL)visible source:(NSString *)source {
    NSString *visibilitySource = source.length > 0 ? source : @"default";
    [self updateStateWithBlock:^{
        if (visible) {
            [self->_homeScreenVisibilitySources addObject:visibilitySource];
        } else {
            [self->_homeScreenVisibilitySources removeObject:visibilitySource];
        }
    }];
}

- (void)noteLockScreenVisible:(BOOL)visible {
    if (visible) {
        [self noteLockScreenVisible:YES source:@"default"];
        return;
    }
    [self updateStateWithBlock:^{
        [self->_lockScreenVisibilitySources removeAllObjects];
    }];
}

- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source {
    NSString *visibilitySource = source.length > 0 ? source : @"default";
    [self updateStateWithBlock:^{
        if (visible) {
            [self->_lockScreenVisibilitySources addObject:visibilitySource];
        } else {
            [self->_lockScreenVisibilitySources removeObject:visibilitySource];
        }
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
    __block BOOL homeScreenVisible = NO;
    __block BOOL strongHomeScreenVisible = NO;
    __block BOOL lockScreenVisible = NO;
    __block BOOL screenBlanked = NO;
    dispatch_sync(_stateQueue, ^{
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        strongHomeScreenVisible = [self strongHomeScreenVisible];
        lockScreenVisible = self->_lockScreenVisibilitySources.count > 0;
        screenBlanked = self->_screenBlanked;
    });
    NSString *eventMode = [self eventModeWithHomeScreenVisible:homeScreenVisible
                                       strongHomeScreenVisible:strongHomeScreenVisible
                                             lockScreenVisible:lockScreenVisible
                                                 screenBlanked:screenBlanked];
    dispatch_sync(_stateQueue, ^{
        self->_lastEventMode = eventMode;
    });
    return eventMode;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    __block BOOL homeScreenVisible = NO;
    __block BOOL strongHomeScreenVisible = NO;
    dispatch_sync(_stateQueue, ^{
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        strongHomeScreenVisible = [self strongHomeScreenVisible];
    });
    if (strongHomeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    if ([self foregroundDisplayIdentifierIgnoringLockState].length > 0) {
        return LAEventModeApplication;
    }
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return LAEventModeSpringBoard;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return [_unlockService supportsUnlockingDeviceToSendEvents];
}

- (NSString *)displayIdentifierForCurrentApplication {
    if ([[self currentEventMode] isEqualToString:LAEventModeLockScreen]) {
        return nil;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState];
}

#if LA_TESTING
- (NSDictionary *)testingDebugDictionary {
    __block NSArray *homeSources = nil;
    __block NSArray *lockSources = nil;
    __block BOOL strongHomeScreenVisible = NO;
    __block BOOL screenBlanked = NO;
    dispatch_sync(_stateQueue, ^{
        homeSources = [[self->_homeScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        lockSources = [[self->_lockScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        strongHomeScreenVisible = [self strongHomeScreenVisible];
        screenBlanked = self->_screenBlanked;
    });

    BOOL uiLocked = [_unlockService isUILocked];
    NSString *frontMost = [self foregroundDisplayIdentifierIgnoringLockState] ?: @"";
    NSString *mode = [self eventModeWithHomeScreenVisible:homeSources.count > 0
                                  strongHomeScreenVisible:strongHomeScreenVisible
                                        lockScreenVisible:lockSources.count > 0
                                            screenBlanked:screenBlanked] ?: @"";
    return @{
        @"Mode" : mode,
        @"HomeSources" : homeSources ?: @[],
        @"StrongHomeScreenVisible" : @(strongHomeScreenVisible),
        @"LockSources" : lockSources ?: @[],
        @"ScreenBlanked" : @(screenBlanked),
        @"UILocked" : @(uiLocked),
        @"FrontMost" : frontMost,
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
    if ([application respondsToSelector:@selector(bundleIdentifier)]) {
        NSString *bundleIdentifier = [application bundleIdentifier];
        if ([bundleIdentifier isKindOfClass:NSString.class] && bundleIdentifier.length > 0) {
            return bundleIdentifier;
        }
    }
    if ([application respondsToSelector:@selector(displayIdentifier)]) {
        NSString *displayIdentifier = [application displayIdentifier];
        if ([displayIdentifier isKindOfClass:NSString.class] && displayIdentifier.length > 0) {
            return displayIdentifier;
        }
    }
    return nil;
}

- (BOOL)strongHomeScreenVisible {
    for (NSString *source in _homeScreenVisibilitySources) {
        if ([source isEqualToString:@"default"]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
                     strongHomeScreenVisible:(BOOL)strongHomeScreenVisible
                           lockScreenVisible:(BOOL)lockScreenVisible
                               screenBlanked:(BOOL)screenBlanked {
    BOOL lockScreenActive = screenBlanked || [_unlockService isUILocked] || (lockScreenVisible && !homeScreenVisible);
    if (lockScreenActive) {
        return LAEventModeLockScreen;
    }
    if (strongHomeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    if ([self foregroundDisplayIdentifierIgnoringLockState].length > 0) {
        return LAEventModeApplication;
    }
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return LAEventModeSpringBoard;
}

- (void)updateStateWithBlock:(void (^)(void))block {
    NSString *previousMode = self.currentEventMode;
    dispatch_sync(_stateQueue, ^{
        block();
    });

    NSString *eventMode = self.currentEventMode;
    __block void (^handler)(NSString *eventMode) = nil;
    dispatch_sync(_stateQueue, ^{
        handler = [self->_eventModeChangeHandler copy];
    });
    if (eventMode.length == 0 || [eventMode isEqualToString:previousMode] || !handler) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(eventMode);
    });
}

@end
