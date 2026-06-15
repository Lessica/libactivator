//
//  LATSystemMainQueueActionPerformer.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemMainQueueActionPerformer.h"

@implementation LATSystemMainQueueActionPerformer

- (BOOL)performOnMainQueueForListenerName:(NSString *)listenerName block:(dispatch_block_t)block {
    (void)listenerName;
    if (!block) {
        return NO;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    return YES;
}

@end
