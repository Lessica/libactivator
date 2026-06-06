//
//  LATouchActivityTracker.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATouchActivityTracker.h"

#import <UIKit/UIKit.h>

@implementation LATouchActivityTracker {
    dispatch_queue_t _queue;
    NSHashTable *_activeTouches;
    NSMutableArray *_pendingBlocks;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("libactivator.touch-activity", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _activeTouches = [[NSHashTable alloc]
            initWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                   capacity:0];
        _pendingBlocks = [NSMutableArray array];
    }
    return self;
}

#pragma mark - State

- (BOOL)isTouchActive {
    __block BOOL touchActive = NO;
    dispatch_sync(_queue, ^{
        touchActive = self->_activeTouches.count > 0;
    });
    return touchActive;
}

- (void)noteTouchEvent:(UIEvent *)event {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSMutableArray *blocksToRun = [NSMutableArray array];
    dispatch_sync(_queue, ^{
        for (UITouch *touch in event.allTouches) {
            if (![touch isKindOfClass:UITouch.class]) {
                continue;
            }
            if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
                [self->_activeTouches removeObject:touch];
            } else {
                [self->_activeTouches addObject:touch];
            }
        }
        if (self->_activeTouches.count == 0 && self->_pendingBlocks.count > 0) {
            [blocksToRun addObjectsFromArray:self->_pendingBlocks];
            [self->_pendingBlocks removeAllObjects];
        }
    });

    for (dispatch_block_t block in blocksToRun) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)performWhenTouchesEnd:(dispatch_block_t)block {
    if (!block) {
        return;
    }

    __block BOOL shouldRunNow = NO;
    dispatch_sync(_queue, ^{
        if (self->_activeTouches.count == 0) {
            shouldRunNow = YES;
        } else {
            [self->_pendingBlocks addObject:[block copy]];
        }
    });
    if (shouldRunNow) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
