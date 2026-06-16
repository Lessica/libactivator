//
//  LATSystemVoiceControlController.m
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemVoiceControlController.h"

#import <HBLog.h>
#import <dlfcn.h>

typedef BOOL (*LATAXSCommandAndControlEnabledFunction)(void);
typedef void (*LATAXSCommandAndControlSetEnabledFunction)(BOOL enabled);

static NSString *const LATAccessibilityLibraryPath = @"/usr/lib/libAccessibility.dylib";
static LATAXSCommandAndControlEnabledFunction gCommandAndControlEnabledFunction = NULL;
static LATAXSCommandAndControlSetEnabledFunction gCommandAndControlSetEnabledFunction = NULL;

@implementation LATSystemVoiceControlController

- (BOOL)toggleVoiceControlForListenerName:(NSString *)listenerName {
    if (![self resolveCommandAndControlFunctionsForListenerName:listenerName]) {
        return NO;
    }

    BOOL enabled = gCommandAndControlEnabledFunction();
    gCommandAndControlSetEnabledFunction(!enabled);
    HBLogDebug(@"Toggled Voice Control to %@ for system action %@", enabled ? @"disabled" : @"enabled",
               listenerName ?: @"");
    return YES;
}

- (BOOL)resolveCommandAndControlFunctionsForListenerName:(NSString *)listenerName {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        void *handle = dlopen(LATAccessibilityLibraryPath.UTF8String, RTLD_LAZY);
        if (!handle) {
            return;
        }

        gCommandAndControlEnabledFunction =
            (LATAXSCommandAndControlEnabledFunction)dlsym(handle, "_AXSCommandAndControlEnabled");
        gCommandAndControlSetEnabledFunction =
            (LATAXSCommandAndControlSetEnabledFunction)dlsym(handle, "_AXSCommandAndControlSetEnabled");
    });

    if (!gCommandAndControlEnabledFunction || !gCommandAndControlSetEnabledFunction) {
        HBLogError(@"CommandAndControl accessibility functions are unavailable for system action %@",
                   listenerName ?: @"");
        return NO;
    }
    return YES;
}

@end
