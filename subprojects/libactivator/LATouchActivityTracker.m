//
//  LATouchActivityTracker.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATouchActivityTracker.h"

#import <UIKit/UIKit.h>

@interface LATouchActivityTracker ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) NSHashTable *activeTouches;
@property(nonatomic, strong) NSMutableArray *pendingBlocks;
@end

@implementation LATouchActivityTracker

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
    dispatch_sync(self.queue, ^{
        touchActive = self.activeTouches.count > 0;
    });
    return touchActive;
}

- (void)noteTouchEvent:(UIEvent *)event {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSMutableArray *blocksToRun = [NSMutableArray array];
    dispatch_sync(self.queue, ^{
        for (UITouch *touch in event.allTouches) {
            if (![touch isKindOfClass:UITouch.class]) {
                continue;
            }
            if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
                [self.activeTouches removeObject:touch];
            } else {
                [self.activeTouches addObject:touch];
            }
        }
        if (self.activeTouches.count == 0 && self.pendingBlocks.count > 0) {
            [blocksToRun addObjectsFromArray:self.pendingBlocks];
            [self.pendingBlocks removeAllObjects];
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
    dispatch_sync(self.queue, ^{
        if (self.activeTouches.count == 0) {
            shouldRunNow = YES;
        } else {
            [self.pendingBlocks addObject:[block copy]];
        }
    });
    if (shouldRunNow) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
