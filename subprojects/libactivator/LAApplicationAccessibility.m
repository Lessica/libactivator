//
//  LAApplicationAccessibility.m
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAApplicationAccessibility.h"

#import <HBLog.h>
#import <dlfcn.h>

static NSString *const LAAccessibilityLibraryPath = @"/usr/lib/libAccessibility.dylib";

typedef BOOL (*LAAXSApplicationAccessibilityEnabledFunction)(void);
typedef void (*LAAXSApplicationAccessibilitySetEnabledFunction)(BOOL enabled);

static LAAXSApplicationAccessibilityEnabledFunction gApplicationAccessibilityEnabledFunction = NULL;
static LAAXSApplicationAccessibilitySetEnabledFunction gApplicationAccessibilitySetEnabledFunction = NULL;

static BOOL LAResolveApplicationAccessibilityFunctions(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        void *handle = dlopen(LAAccessibilityLibraryPath.UTF8String, RTLD_LAZY);
        if (!handle) {
            return;
        }
        gApplicationAccessibilityEnabledFunction =
            (LAAXSApplicationAccessibilityEnabledFunction)dlsym(handle, "_AXSApplicationAccessibilityEnabled");
        gApplicationAccessibilitySetEnabledFunction =
            (LAAXSApplicationAccessibilitySetEnabledFunction)dlsym(handle, "_AXSApplicationAccessibilitySetEnabled");
    });

    if (!gApplicationAccessibilityEnabledFunction || !gApplicationAccessibilitySetEnabledFunction) {
        HBLogError(@"Application accessibility functions are unavailable");
        return NO;
    }
    return YES;
}

@implementation LAApplicationAccessibility

+ (BOOL)isEnabled {
    if (!LAResolveApplicationAccessibilityFunctions()) {
        return NO;
    }
    return gApplicationAccessibilityEnabledFunction();
}

+ (BOOL)setEnabled:(BOOL)enabled {
    if (!LAResolveApplicationAccessibilityFunctions()) {
        return NO;
    }
    gApplicationAccessibilitySetEnabledFunction(enabled);
    HBLogDebug(@"Set application accessibility to %@", enabled ? @"enabled" : @"disabled");
    return YES;
}

@end
