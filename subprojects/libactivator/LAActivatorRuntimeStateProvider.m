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
- (NSString *)foregroundDisplayIdentifierIgnoringLockState;
- (NSString *)displayIdentifierForApplication:(id<LAActivatorSpringBoardApplication>)application;
- (NSString *)eventModeWithScreenOn:(BOOL)screenOn uiLocked:(BOOL)uiLocked;
- (void)updateVisibilitySet:(NSMutableSet *)visibilitySet visible:(BOOL)visible source:(NSString *)source;
- (void)updateStateWithBlock:(void (^)(void))block;
@end

@implementation LAActivatorRuntimeStateProvider {
    NSMutableSet *_homeScreenVisibilitySources;
    NSMutableSet *_springBoardInterfaceVisibilitySources;
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
        _springBoardInterfaceVisibilitySources = [[NSMutableSet alloc] init];
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
    __block BOOL screenOn = YES;
    dispatch_sync(_stateQueue, ^{
        screenOn = !self->_screenBlanked;
    });
    return [self eventModeWithScreenOn:screenOn uiLocked:[_unlockService isUILocked]];
}

- (NSString *)currentEventModeUnderneathLockScreen {
    __block BOOL homeScreenVisible = NO;
    __block BOOL springBoardInterfaceVisible = NO;
    dispatch_sync(_stateQueue, ^{
        homeScreenVisible = self->_homeScreenVisibilitySources.count > 0;
        springBoardInterfaceVisible = self->_springBoardInterfaceVisibilitySources.count > 0;
    });
    if (homeScreenVisible || springBoardInterfaceVisible) {
        return LAEventModeSpringBoard;
    }
    if ([self foregroundDisplayIdentifierIgnoringLockState].length > 0) {
        return LAEventModeApplication;
    }
    return LAEventModeSpringBoard;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return [_unlockService supportsUnlockingDeviceToSendEvents];
}

- (NSString *)displayIdentifierForCurrentApplication {
    if (![[self currentEventMode] isEqualToString:LAEventModeApplication]) {
        return nil;
    }
    return [self foregroundDisplayIdentifierIgnoringLockState];
}

#if LA_TESTING
- (NSDictionary *)testingDebugDictionary {
    __block NSArray *homeSources = nil;
    __block NSArray *springBoardInterfaceSources = nil;
    __block NSArray *lockSources = nil;
    __block BOOL screenOn = YES;
    dispatch_sync(_stateQueue, ^{
        homeSources = [[self->_homeScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        springBoardInterfaceSources =
            [[self->_springBoardInterfaceVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        lockSources = [[self->_lockScreenVisibilitySources allObjects] sortedArrayUsingSelector:@selector(compare:)];
        screenOn = !self->_screenBlanked;
    });

    BOOL uiLocked = [_unlockService isUILocked];
    BOOL springBoardInterfaceVisible = homeSources.count > 0 || springBoardInterfaceSources.count > 0;
    NSString *frontMost = [self foregroundDisplayIdentifierIgnoringLockState] ?: @"";
    NSString *mode = [self eventModeWithScreenOn:screenOn uiLocked:uiLocked] ?: @"";
    return @{
        @"Mode" : mode,
        @"UnderneathMode" : self.currentEventModeUnderneathLockScreen ?: @"",
        @"DisplayIdentifier" : self.displayIdentifierForCurrentApplication ?: @"",
        @"HomeSources" : homeSources ?: @[],
        @"SpringBoardInterfaceSources" : springBoardInterfaceSources ?: @[],
        @"LockSources" : lockSources ?: @[],
        @"ScreenOn" : @(screenOn),
        @"LockScreenVisible" : @(lockSources.count > 0),
        @"SpringBoardInterfaceVisible" : @(springBoardInterfaceVisible),
        @"InLockScreen" : @(!screenOn || uiLocked),
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

- (NSString *)eventModeWithScreenOn:(BOOL)screenOn uiLocked:(BOOL)uiLocked {
    if (!screenOn || uiLocked) {
        return LAEventModeLockScreen;
    }
    return [self currentEventModeUnderneathLockScreen];
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
    dispatch_sync(_stateQueue, ^{
        previousMode = [self->_lastEventMode copy];
        block();
    });

    NSString *eventMode = self.currentEventMode;
    __block void (^handler)(NSString *eventMode) = nil;
    dispatch_sync(_stateQueue, ^{
        if (eventMode.length > 0 && ![eventMode isEqualToString:self->_lastEventMode]) {
            self->_lastEventMode = [eventMode copy];
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
