//
//  LAActivatorRuntimeStateProvider.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorRuntimeStateProvider.h"
#import "LAActivatorUnlockService.h"

#import <objc/message.h>
#import <UIKit/UIKit.h>

@interface LAActivatorRuntimeStateProvider ()
- (NSString *)foregroundDisplayIdentifierIgnoringLockState;
- (NSString *)displayIdentifierForApplication:(id)application;
- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
                           lockScreenVisible:(BOOL)lockScreenVisible
                               screenBlanked:(BOOL)screenBlanked;
- (void)updateStateWithBlock:(void (^)(void))block;
@end

@implementation LAActivatorRuntimeStateProvider {
    BOOL _runningInsideSpringBoard;
    BOOL _homeScreenVisible;
    BOOL _lockScreenVisible;
    BOOL _screenBlanked;
    dispatch_queue_t _stateQueue;
    NSString *_lastEventMode;
    void (^_eventModeChangeHandler)(NSString *eventMode);
    LAActivatorUnlockService *_unlockService;
}

#pragma mark - Lifecycle

- (instancetype)initWithSpringBoardRole:(BOOL)runningInsideSpringBoard {
    self = [super init];
    if (self) {
        _runningInsideSpringBoard = runningInsideSpringBoard;
        _homeScreenVisible = runningInsideSpringBoard;
        _stateQueue = dispatch_queue_create("libactivator.runtime-state", DISPATCH_QUEUE_SERIAL);
        _unlockService = [[LAActivatorUnlockService alloc] initWithSpringBoardRole:runningInsideSpringBoard];
        _lastEventMode = runningInsideSpringBoard ? LAEventModeSpringBoard : LAEventModeApplication;
    }
    return self;
}

#pragma mark - Updates

- (void)noteHomeScreenVisible:(BOOL)visible {
    [self updateStateWithBlock:^{
      self->_homeScreenVisible = visible;
    }];
}

- (void)noteLockScreenVisible:(BOOL)visible {
    [self updateStateWithBlock:^{
      self->_lockScreenVisible = visible;
    }];
}

- (void)noteScreenBlanked:(BOOL)blanked {
    [self updateStateWithBlock:^{
      self->_screenBlanked = blanked;
    }];
}

- (void)noteRuntimeStateMayHaveChanged {
    [self updateStateWithBlock:^{}];
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
      homeScreenVisible = self->_homeScreenVisible;
      lockScreenVisible = self->_lockScreenVisible;
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
    if (!_runningInsideSpringBoard) {
        return LAEventModeApplication;
    }

    __block BOOL homeScreenVisible = NO;
    dispatch_sync(_stateQueue, ^{
      homeScreenVisible = self->_homeScreenVisible;
    });
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState].length > 0 ? LAEventModeApplication : LAEventModeSpringBoard;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return [_unlockService supportsUnlockingDeviceToSendEvents];
}

- (NSString *)displayIdentifierForCurrentApplication {
    if (!_runningInsideSpringBoard) {
        return [[NSBundle mainBundle] bundleIdentifier];
    }

    if ([[self currentEventMode] isEqualToString:LAEventModeLockScreen]) {
        return nil;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState];
}

#pragma mark - Private

- (NSString *)foregroundDisplayIdentifierIgnoringLockState {
    if (!_runningInsideSpringBoard) {
        return [[NSBundle mainBundle] bundleIdentifier];
    }

    __block NSString *displayIdentifier = nil;
    dispatch_block_t block = ^{
      UIApplication *application = [UIApplication sharedApplication];
      if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
          return;
      }

      id frontMostApplication =
          ((id (*)(id, SEL))objc_msgSend)(application, @selector(_accessibilityFrontMostApplication));
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

- (NSString *)displayIdentifierForApplication:(id)application {
    if ([application respondsToSelector:@selector(bundleIdentifier)]) {
        NSString *bundleIdentifier = ((id (*)(id, SEL))objc_msgSend)(application, @selector(bundleIdentifier));
        if ([bundleIdentifier isKindOfClass:NSString.class] && bundleIdentifier.length > 0) {
            return bundleIdentifier;
        }
    }
    if ([application respondsToSelector:@selector(displayIdentifier)]) {
        NSString *displayIdentifier = ((id (*)(id, SEL))objc_msgSend)(application, @selector(displayIdentifier));
        if ([displayIdentifier isKindOfClass:NSString.class] && displayIdentifier.length > 0) {
            return displayIdentifier;
        }
    }
    return nil;
}

- (NSString *)eventModeWithHomeScreenVisible:(BOOL)homeScreenVisible
                           lockScreenVisible:(BOOL)lockScreenVisible
                               screenBlanked:(BOOL)screenBlanked {
    if (!_runningInsideSpringBoard) {
        return LAEventModeApplication;
    }

    BOOL lockScreenActive = lockScreenVisible || screenBlanked || [_unlockService isUILocked];
    if (lockScreenActive) {
        return LAEventModeLockScreen;
    }
    if (homeScreenVisible) {
        return LAEventModeSpringBoard;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState].length > 0 ? LAEventModeApplication : LAEventModeSpringBoard;
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
