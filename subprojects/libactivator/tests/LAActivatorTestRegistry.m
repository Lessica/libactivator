//
//  LAActivatorTestRegistry.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorTestRegistry.h"

#if LIBACTIVATOR_TEST_SUPPORT

#import "LATestRecorder.h"

#import <Activator/Activator.h>

static NSString *const LAActivatorTestGroupIdentifierKey = @"Identifier";
static NSString *const LAActivatorTestGroupCleanupBlockKey = @"CleanupBlock";
static NSString *const LAActivatorTestGroupStableTestsBlockKey = @"StableTestsBlock";
static NSString *const LAActivatorTestGroupDeviceRuntimeTestsBlockKey = @"DeviceRuntimeTestsBlock";
static NSMutableArray<NSDictionary<NSString *, id> *> *sLAActivatorTestGroups = nil;

@implementation LAActivatorTestRegistry

+ (BOOL)registerGroupWithIdentifier:(NSString *)identifier
                       cleanupBlock:(LAActivatorTestGroupCleanupBlock)cleanupBlock
                   stableTestsBlock:(LAActivatorTestGroupRunBlock)stableTestsBlock
            deviceRuntimeTestsBlock:(LAActivatorTestGroupRunBlock)deviceRuntimeTestsBlock {
    if (identifier.length == 0 || !cleanupBlock || (!stableTestsBlock && !deviceRuntimeTestsBlock)) {
        return NO;
    }

    if (!sLAActivatorTestGroups) {
        sLAActivatorTestGroups = [[NSMutableArray alloc] init];
    }
    for (NSDictionary<NSString *, id> *group in sLAActivatorTestGroups) {
        if ([group[LAActivatorTestGroupIdentifierKey] isEqualToString:identifier]) {
            return NO;
        }
    }

    NSMutableDictionary<NSString *, id> *group = [@{
        LAActivatorTestGroupIdentifierKey : [identifier copy],
        LAActivatorTestGroupCleanupBlockKey : [cleanupBlock copy],
    } mutableCopy];
    if (stableTestsBlock) {
        group[LAActivatorTestGroupStableTestsBlockKey] = [stableTestsBlock copy];
    }
    if (deviceRuntimeTestsBlock) {
        group[LAActivatorTestGroupDeviceRuntimeTestsBlockKey] = [deviceRuntimeTestsBlock copy];
    }
    [sLAActivatorTestGroups addObject:[group copy]];
    return YES;
}

+ (BOOL)hasRegisteredGroups {
    return sLAActivatorTestGroups.count > 0;
}

+ (void)cleanupRegisteredGroupsWithActivator:(LAActivator *)activator {
    for (NSDictionary<NSString *, id> *group in [sLAActivatorTestGroups copy]) {
        LAActivatorTestGroupCleanupBlock cleanupBlock = group[LAActivatorTestGroupCleanupBlockKey];
        cleanupBlock(activator);
    }
}

+ (void)runRegisteredStableTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    for (NSDictionary<NSString *, id> *group in [sLAActivatorTestGroups copy]) {
        LAActivatorTestGroupRunBlock runBlock = group[LAActivatorTestGroupStableTestsBlockKey];
        if (runBlock) {
            runBlock(recorder, activator);
        }
    }
}

+ (void)runRegisteredDeviceRuntimeTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    for (NSDictionary<NSString *, id> *group in [sLAActivatorTestGroups copy]) {
        LAActivatorTestGroupRunBlock runBlock = group[LAActivatorTestGroupDeviceRuntimeTestsBlockKey];
        if (runBlock) {
            runBlock(recorder, activator);
        }
    }
}

@end

#endif
