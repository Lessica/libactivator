//
//  LARuntimeContext.m
//  libactivator
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LARuntimeContext.h"

#import "LAQueueAssertions.h"

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

@end

@implementation LARuntimeContext

- (instancetype)init {
    self = [super init];
    if (self) {
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
    LAAssertMainQueue();

    NSString *effectiveMode = eventMode.length > 0 ? eventMode : LAEventModeSpringBoard;
    NSString *effectiveUnderneathMode = underneathMode.length > 0 ? underneathMode : LAEventModeSpringBoard;
    NSString *effectiveDisplayIdentifier = displayIdentifier.length > 0 ? displayIdentifier : nil;

    NSString *previousMode = [self.cachedEventMode copy];
    self.cachedEventMode = [effectiveMode copy];
    self.cachedEventModeUnderneathLockScreen = [effectiveUnderneathMode copy];
    self.cachedDisplayIdentifier = [effectiveDisplayIdentifier copy];
    self.cachedScreenOn = screenOn;

    NSString *changedEventMode = nil;
    if (![effectiveMode isEqualToString:previousMode]) {
        changedEventMode = [effectiveMode copy];
    }

    void (^changeHandler)(NSString *eventMode) = [self->_eventModeChangeHandler copy];
    if (changedEventMode.length > 0 && changeHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            changeHandler(changedEventMode);
        });
    }
    return changedEventMode;
}

- (void)setEventModeChangeHandler:(void (^)(NSString *eventMode))handler {
    LAAssertMainQueue();
    _eventModeChangeHandler = [handler copy];
}

- (void)setTouchActivityProvider:(BOOL (^)(void))touchActiveProvider
           touchesEndedPerformer:(void (^)(dispatch_block_t block))touchesEndedPerformer {
    LAAssertMainQueue();
    self.touchActiveProvider = [touchActiveProvider copy];
    self.touchesEndedPerformer = [touchesEndedPerformer copy];
}

- (NSString *)currentEventMode {
    LAAssertMainQueue();
    return [self.cachedEventMode copy] ?: LAEventModeSpringBoard;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    LAAssertMainQueue();
    return [self.cachedEventModeUnderneathLockScreen copy] ?: LAEventModeSpringBoard;
}

- (NSString *)displayIdentifierForCurrentApplication {
    LAAssertMainQueue();
    return [self.cachedDisplayIdentifier copy];
}

- (BOOL)screenIsOn {
    LAAssertMainQueue();
    return self.cachedScreenOn;
}

- (BOOL)touchActive {
    LAAssertMainQueue();
    BOOL (^provider)(void) = self.touchActiveProvider;
    return provider ? provider() : NO;
}

- (void)performWhenTouchesEnd:(dispatch_block_t)block {
    LAAssertMainQueue();

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
    LAAssertMainQueue();

    NSString *mode = [self.cachedEventMode copy];
    NSString *underneathMode = [self.cachedEventModeUnderneathLockScreen copy];
    NSString *displayIdentifier = [self.cachedDisplayIdentifier copy];
    BOOL screenOn = self.cachedScreenOn;
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
