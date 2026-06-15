//
//  LATSystemAssistantController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemAssistantController.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (BOOL)isSiriVisible;
- (BOOL)dismissSiri;
@end

@interface AXPISystemActionHelper : NSObject
+ (instancetype)sharedInstance;
- (void)activateSiri;
@end

@implementation LATSystemAssistantController

- (BOOL)activateVirtualAssistantForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    if ([server respondsToSelector:@selector(isSiriVisible)] && [server isSiriVisible]) {
        if ([server respondsToSelector:@selector(dismissSiri)] && [server dismissSiri]) {
            return YES;
        }
        HBLogError(@"AXSpringBoardServer cannot dismiss Siri for system action %@", listenerName ?: @"");
        return YES;
    }

    AXPISystemActionHelper *helper =
        [self accessibilityPhysicalInteractionSystemActionHelperForListenerName:listenerName];
    if (![helper respondsToSelector:@selector(activateSiri)]) {
        HBLogError(@"AXPISystemActionHelper cannot activate Siri for system action %@", listenerName ?: @"");
        return YES;
    }
    [helper activateSiri];
    return YES;
}

- (nullable AXSpringBoardServer *)axSpringBoardServerForListenerName:(NSString *)listenerName {
    Class serverClass = NSClassFromString(@"AXSpringBoardServer");
    if (![serverClass respondsToSelector:@selector(server)]) {
        HBLogError(@"AXSpringBoardServer is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(id)serverClass server];
}

- (nullable AXPISystemActionHelper *)accessibilityPhysicalInteractionSystemActionHelperForListenerName:
    (NSString *)listenerName {
    NSString *frameworkPath = @"/System/Library/PrivateFrameworks/AccessibilityPhysicalInteraction.framework";
    NSBundle *frameworkBundle = [NSBundle bundleWithPath:frameworkPath];
    if (!frameworkBundle.loaded) {
        NSError *error = nil;
        if (![frameworkBundle loadAndReturnError:&error]) {
            HBLogError(@"AccessibilityPhysicalInteraction.framework is unavailable for system action %@: %@",
                       listenerName ?: @"", error.localizedDescription ?: @"unknown error");
            return nil;
        }
    }

    Class helperClass = NSClassFromString(@"AXPISystemActionHelper");
    if (![helperClass respondsToSelector:@selector(sharedInstance)]) {
        HBLogError(@"AXPISystemActionHelper is unavailable for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(id)helperClass sharedInstance];
}

@end
