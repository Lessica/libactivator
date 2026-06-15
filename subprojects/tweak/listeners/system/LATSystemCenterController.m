//
//  LATSystemCenterController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemCenterController.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (BOOL)isControlCenterVisible;
- (BOOL)showControlCenter:(BOOL)show;
- (BOOL)isNotificationCenterVisible;
- (void)showNotificationCenter;
- (BOOL)showNotificationCenter:(BOOL)show;
- (void)hideNotificationCenter;
- (void)toggleNotificationCenter;
@end

@implementation LATSystemCenterController

- (BOOL)activateControlCenterForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    BOOL visible = NO;
    if ([server respondsToSelector:@selector(isControlCenterVisible)]) {
        visible = [server isControlCenterVisible];
    }
    if (![server respondsToSelector:@selector(showControlCenter:)]) {
        HBLogError(@"AXSpringBoardServer cannot toggle Control Center for system action %@", listenerName ?: @"");
        return YES;
    }
    if (![server showControlCenter:!visible]) {
        HBLogWarn(@"AXSpringBoardServer refused to toggle Control Center for system action %@", listenerName ?: @"");
    }
    return YES;
}

- (BOOL)activateNotificationCenterForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    BOOL visibilityKnown = [server respondsToSelector:@selector(isNotificationCenterVisible)];
    BOOL visible = visibilityKnown ? [server isNotificationCenterVisible] : NO;
    if (visibilityKnown && visible) {
        if ([server respondsToSelector:@selector(hideNotificationCenter)]) {
            [server hideNotificationCenter];
            return YES;
        }
        if ([server respondsToSelector:@selector(showNotificationCenter:)]) {
            if (![server showNotificationCenter:NO]) {
                HBLogWarn(@"AXSpringBoardServer refused to hide Notification Center for system action %@",
                          listenerName ?: @"");
            }
            return YES;
        }
        if ([server respondsToSelector:@selector(toggleNotificationCenter)]) {
            [server toggleNotificationCenter];
            return YES;
        }
        HBLogError(@"AXSpringBoardServer cannot hide Notification Center for system action %@", listenerName ?: @"");
        return YES;
    }
    if ([server respondsToSelector:@selector(showNotificationCenter:)]) {
        if (![server showNotificationCenter:YES]) {
            HBLogWarn(@"AXSpringBoardServer refused to show Notification Center for system action %@",
                      listenerName ?: @"");
        }
        return YES;
    }
    if ([server respondsToSelector:@selector(showNotificationCenter)]) {
        [server showNotificationCenter];
        return YES;
    }
    if ([server respondsToSelector:@selector(toggleNotificationCenter)]) {
        [server toggleNotificationCenter];
        return YES;
    }
    HBLogError(@"AXSpringBoardServer cannot toggle Notification Center for system action %@", listenerName ?: @"");
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

@end
