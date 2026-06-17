//
//  LATSystemOrientationController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemOrientationController.h"

#import <HBLog.h>

@interface AXSpringBoardServer : NSObject
+ (instancetype)server;
- (void)setOrientation:(long long)orientation;
@end

@implementation LATSystemOrientationController

- (BOOL)rotateToOrientation:(NSInteger)orientation listenerName:(NSString *)listenerName {
    AXSpringBoardServer *server = [self axSpringBoardServerForListenerName:listenerName];
    if (![server respondsToSelector:@selector(setOrientation:)]) {
        HBLogError(@"AXSpringBoardServer cannot set orientation for system action %@", listenerName ?: @"");
        return NO;
    }
    [server setOrientation:orientation];
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
