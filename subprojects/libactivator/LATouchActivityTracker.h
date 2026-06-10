//
//  LATouchActivityTracker.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIEvent;

__attribute__((visibility("hidden")))
@interface LATouchActivityTracker : NSObject

#pragma mark - State

@property(nonatomic, readonly, getter=isTouchActive) BOOL touchActive;

#pragma mark - Updates

- (void)noteTouchEvent:(UIEvent *)event;
- (void)performWhenTouchesEnd:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
