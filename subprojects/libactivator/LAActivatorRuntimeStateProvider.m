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
- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
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
    [self noteHomeScreenVisible:visible source:@"default"];
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
    [self noteLockScreenVisible:visible source:@"default"];
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
    __block BOOL lockScreenVisible = NO;
    __block BOOL screenBlanked = NO;
    dispatch_sync(_stateQueue, ^{
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        lockScreenVisible = self->_lockScreenVisibilitySources.count > 0;
        screenBlanked = self->_screenBlanked;
    });
    NSString *eventMode = [self eventModeWithHomeScreenVisible:homeScreenVisible
                                             lockScreenVisible:lockScreenVisible
                                                 screenBlanked:screenBlanked];
    dispatch_sync(_stateQueue, ^{
        self->_lastEventMode = eventMode;
    });
    return eventMode;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    __block BOOL homeScreenVisible = NO;
    dispatch_sync(_stateQueue, ^{
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
    });
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState].length > 0 ? LAEventModeApplication
                                                                          : LAEventModeSpringBoard;
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

- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
                           lockScreenVisible:(BOOL)lockScreenVisible
                               screenBlanked:(BOOL)screenBlanked {
    BOOL lockScreenActive = lockScreenVisible || screenBlanked || [_unlockService isUILocked];
    if (lockScreenActive) {
        return LAEventModeLockScreen;
    }
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState].length > 0 ? LAEventModeApplication
                                                                          : LAEventModeSpringBoard;
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
