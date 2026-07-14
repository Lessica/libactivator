//
//  LATestEnvironment.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEnvironment.h"

#import "LAActivator+Private.h"
#import "LARuntimeContext.h"

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>
#import <roothide.h>

@implementation LATestEnvironment

+ (LARuntimeContext *)runtimeContextForActivator:(LAActivator *)activator {
    LARuntimeContext *runtimeContext = [activator la_runtimeContext];
    NSCAssert(runtimeContext, @"Runtime context must be available in SpringBoard-owned tests");
    return runtimeContext;
}

+ (NSDictionary<NSString *, id> *)runtimeInputStateSnapshotWithActivator:(LAActivator *)activator {
    LARuntimeContext *runtimeContext = [self runtimeContextForActivator:activator];
    return @{
        @"Mode" : runtimeContext.currentEventMode,
        @"UnderneathMode" : runtimeContext.currentEventModeUnderneathLockScreen,
        @"DisplayIdentifier" : runtimeContext.displayIdentifierForCurrentApplication ?: NSNull.null,
        @"ScreenOn" : @(runtimeContext.screenIsOn),
    };
}

+ (void)restoreRuntimeInputStateSnapshot:(NSDictionary<NSString *, id> *)snapshot activator:(LAActivator *)activator {
    NSString *mode = [snapshot[@"Mode"] isKindOfClass:NSString.class] ? snapshot[@"Mode"] : LAEventModeSpringBoard;
    NSString *underneathMode = [snapshot[@"UnderneathMode"] isKindOfClass:NSString.class] ? snapshot[@"UnderneathMode"]
                                                                                          : LAEventModeSpringBoard;
    NSString *displayIdentifier =
        [snapshot[@"DisplayIdentifier"] isKindOfClass:NSString.class] ? snapshot[@"DisplayIdentifier"] : nil;
    NSNumber *screenOn = [snapshot[@"ScreenOn"] isKindOfClass:NSNumber.class] ? snapshot[@"ScreenOn"] : @YES;
    [[self runtimeContextForActivator:activator] updateEventMode:mode
                                            underneathLockScreen:underneathMode
                                               displayIdentifier:displayIdentifier
                                                        screenOn:screenOn.boolValue];
}

#pragma mark - Cleanup

+ (NSString *)testCachePathWithFileName:(NSString *)fileName {
    if (fileName.length == 0) {
        return nil;
    }
    return [@"/var/mobile/Library/Caches" stringByAppendingPathComponent:fileName];
}

+ (void)cleanActivator:(LAActivator *)activator {
    NSArray<NSString *> *listenerNames = @[
        @"libactivator.test.listener.a",
        @"libactivator.test.listener.b",
        @"libactivator.test.listener.c",
        @"libactivator.test.listener.unseen",
        @"libactivator.test.listener.new",
        @"libactivator.test.listener.localization",
        @"libactivator.test.listener.icon",
        @"libactivator.test.dispatch.a",
        @"libactivator.test.dispatch.b",
        @"libactivator.test.dispatch.shared.first",
        @"libactivator.test.dispatch.shared.second",
        @"libactivator.test.dispatch.simple-abort",
        @"libactivator.test.dispatch.lock",
        @"libactivator.test.dispatch.unlock",
        @"libactivator.test.client-facade.user-info",
    ];
    NSArray<NSString *> *eventNames = @[
        @"libactivator.test.core",
        @"libactivator.test.removable-event",
        @"libactivator.test.nonremovable-event",
        @"libactivator.test.new-event-data-source",
        @"libactivator.test.owner-safe-event",
        @"libactivator.test.configuration-event",
        @"libactivator.test.dispatch",
        @"libactivator.test.client-facade.user-info",
        @"libactivator.test.client-facade.configuration",
    ];

    for (NSString *eventName in eventNames) {
        [activator la_unassignEventNameFromAllProfilesAndNotifyIfChanged:eventName];
        [activator unregisterEventDataSourceWithEventName:eventName];
    }
    for (NSString *listenerName in listenerNames) {
        [activator _setObject:nil forPreference:[NSString stringWithFormat:@"LAHasSeenListener-%@", listenerName]];
        [activator unregisterListenerWithName:listenerName];
    }
    [activator la_resetDispatchCounts];
}

+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator {
    [[self runtimeContextForActivator:activator] updateEventMode:LAEventModeSpringBoard
                                            underneathLockScreen:LAEventModeSpringBoard
                                               displayIdentifier:nil
                                                        screenOn:YES];
}

+ (void)removeTestPlist {
    [NSFileManager.defaultManager removeItemAtPath:[self testCachePathWithFileName:@"libactivator.tests.plist"]
                                             error:nil];
    [NSFileManager.defaultManager removeItemAtPath:jbroot(@"/var/mobile/Library/Preferences/libactivator-tests.plist")
                                             error:nil];
}

+ (NSString *)runtimeDebugReasonWithPrefix:(NSString *)prefix activator:(LAActivator *)activator {
    NSDictionary *state = [[self runtimeContextForActivator:activator] testingDebugDictionary];
    return [NSString stringWithFormat:@"%@; mode=%@; homeSources=%@; springBoardSources=%@; lockSources=%@; "
                                      @"screenOn=%@; uiLocked=%@; frontMost=%@",
                                      prefix ?: @"Runtime mode mismatch", state[@"Mode"] ?: @"",
                                      state[@"HomeSources"] ?: @[], state[@"SpringBoardInterfaceSources"] ?: @[],
                                      state[@"LockSources"] ?: @[], state[@"ScreenOn"] ?: @NO,
                                      state[@"UILocked"] ?: @NO, state[@"FrontMost"] ?: @""];
}

#pragma mark - Synchronization Helpers

+ (void)performOnMainThreadSynchronously:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if (NSThread.isMainThread) {
        block();
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), block);
}

+ (BOOL)waitUntilTrue:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout {
    if (!predicate) {
        return NO;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!predicate()) {
        if ([deadline timeIntervalSinceNow] <= 0.0) {
            return NO;
        }
        [self waitAllowingMainRunLoopForTimeInterval:0.05];
    }
    return YES;
}

+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval {
    if (timeInterval <= 0) {
        return;
    }
    if (!NSThread.isMainThread) {
        [NSThread sleepForTimeInterval:timeInterval];
        return;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    while ([deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

+ (void)waitForMainQueue {
    if (!NSThread.isMainThread) {
        dispatch_sync(dispatch_get_main_queue(), ^{
                          // No work needed; just waiting for the main queue to be idle.
                      });
        return;
    }

    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        drained = YES;
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!drained && [deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end
