//
//  LARuntimeContext.m
//  libactivator
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LARuntimeContext.h"

#import <Activator/Activator.h>

@interface LARuntimeContext ()

// Caches
@property(nonatomic, copy) NSString *cachedEventMode;
@property(nonatomic, copy) NSString *cachedEventModeUnderneathLockScreen;
@property(nonatomic, copy, nullable) NSString *cachedDisplayIdentifier;
@property(nonatomic, assign) BOOL cachedScreenOn;

// Handlers
@property(nonatomic, copy, nullable) void (^eventModeChangeHandler)(NSString *eventMode);
@property(nonatomic, copy, nullable) BOOL (^touchActiveProvider)(void);
@property(nonatomic, copy, nullable) void (^touchesEndedPerformer)(dispatch_block_t block);

// Concurrency
@property(nonatomic, strong) dispatch_queue_t queue;

@end

@implementation LARuntimeContext

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("libactivator.runtime-context", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _cachedEventMode = LAEventModeSpringBoard;
        _cachedEventModeUnderneathLockScreen = LAEventModeSpringBoard;
        _cachedScreenOn = YES;
    }
    return self;
}

- (NSString *)updateEventMode:(NSString *)eventMode
         underneathLockScreen:(NSString *)underneathMode
            displayIdentifier:(NSString *)displayIdentifier
                     screenOn:(BOOL)screenOn {
    NSString *effectiveMode = eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
    NSString *effectiveUnderneathMode = underneathMode.length > 0 ? underneathMode : LAEventModeSpringBoard;
    NSString *effectiveDisplayIdentifier = displayIdentifier.length > 0 ? displayIdentifier : nil;
    __block NSString *changedEventMode = nil;
    __block void (^changeHandler)(NSString *eventMode) = nil;
    dispatch_sync(self.queue, ^{
        NSString *previousMode = [self->_cachedEventMode copy];
        self->_cachedEventMode = [effectiveMode copy];
        self->_cachedEventModeUnderneathLockScreen = [effectiveUnderneathMode copy];
        self->_cachedDisplayIdentifier = [effectiveDisplayIdentifier copy];
        self->_cachedScreenOn = screenOn;
        if (![effectiveMode isEqualToString:previousMode]) {
            changedEventMode = [effectiveMode copy];
            changeHandler = [self->_eventModeChangeHandler copy];
        }
    });
    if (changedEventMode.length > 0 && changeHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            changeHandler(changedEventMode);
        });
    }
    return changedEventMode;
}

- (void)setEventModeChangeHandler:(void (^)(NSString *eventMode))handler {
    dispatch_sync(self.queue, ^{
        self->_eventModeChangeHandler = [handler copy];
    });
}

- (void)setTouchActivityProvider:(BOOL (^)(void))touchActiveProvider
           touchesEndedPerformer:(void (^)(dispatch_block_t block))touchesEndedPerformer {
    self.touchActiveProvider = [touchActiveProvider copy];
    self.touchesEndedPerformer = [touchesEndedPerformer copy];
}

- (NSString *)currentEventMode {
    __block NSString *eventMode = nil;
    dispatch_sync(self.queue, ^{
        eventMode = [self->_cachedEventMode copy];
    });
    return eventMode ?: LAEventModeSpringBoard;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    __block NSString *eventMode = nil;
    dispatch_sync(self.queue, ^{
        eventMode = [self->_cachedEventModeUnderneathLockScreen copy];
    });
    return eventMode ?: LAEventModeSpringBoard;
}

- (NSString *)displayIdentifierForCurrentApplication {
    __block NSString *displayIdentifier = nil;
    dispatch_sync(self.queue, ^{
        displayIdentifier = [self->_cachedDisplayIdentifier copy];
    });
    return displayIdentifier;
}

- (BOOL)screenIsOn {
    __block BOOL screenOn = YES;
    dispatch_sync(self.queue, ^{
        screenOn = self->_cachedScreenOn;
    });
    return screenOn;
}

- (BOOL)touchActive {
    BOOL (^provider)(void) = self.touchActiveProvider;
    return provider ? provider() : NO;
}

- (void)performWhenTouchesEnd:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    void (^performer)(dispatch_block_t block) = self.touchesEndedPerformer;
    if (performer) {
        performer(block);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), block);
}

#if LIBACTIVATOR_TEST_SUPPORT
- (NSDictionary *)testingDebugDictionary {
    __block NSString *mode = nil;
    __block NSString *underneathMode = nil;
    __block NSString *displayIdentifier = nil;
    __block BOOL screenOn = YES;
    dispatch_sync(self.queue, ^{
        mode = [self->_cachedEventMode copy];
        underneathMode = [self->_cachedEventModeUnderneathLockScreen copy];
        displayIdentifier = [self->_cachedDisplayIdentifier copy];
        screenOn = self->_cachedScreenOn;
    });
    return @{
        @"Mode" : mode ?: @"",
        @"UnderneathMode" : underneathMode ?: @"",
        @"DisplayIdentifier" : displayIdentifier ?: @"",
        @"ScreenOn" : @(screenOn),
        @"HomeSources" : @[],
        @"SpringBoardInterfaceSources" : @[],
        @"LockSources" : @[],
        @"LockScreenVisible" : @([mode isEqualToString:LAEventModeLockScreen]),
        @"SpringBoardInterfaceVisible" : @([mode isEqualToString:LAEventModeSpringBoard]),
        @"InLockScreen" : @([mode isEqualToString:LAEventModeLockScreen]),
        @"UILocked" : @([mode isEqualToString:LAEventModeLockScreen]),
        @"FrontMost" : displayIdentifier ?: @"",
    };
}
#endif

@end
