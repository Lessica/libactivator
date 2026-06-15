//
//  LATSystemWalletController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemWalletController.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (void)armApplePay;
@end

@implementation LATSystemWalletController

- (BOOL)activateWalletForListenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    if (![server respondsToSelector:@selector(armApplePay)]) {
        HBLogError(@"AXSpringBoardServer cannot arm Apple Pay for system action %@", listenerName ?: @"");
        return YES;
    }
    [server armApplePay];
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
