//
//  LATRuntimeStateSource.h
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIEvent;
@class LARuntimeContext;

@interface LATRuntimeStateSource : NSObject

#pragma mark - Lifecycle

- (instancetype)initWithRuntimeContext:(nullable LARuntimeContext *)runtimeContext;

// Main-queue confined. This source feeds runtime state and dispatch gates; it does not send public events.
- (void)start;
- (void)refreshForegroundDisplayIdentifier;

#pragma mark - Runtime Updates

- (void)noteHomeScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteSpringBoardInterfaceVisible:(BOOL)visible source:(NSString *)source;
- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteUILocked:(BOOL)uiLocked;
- (void)noteSystemTouchEvent:(UIEvent *)event;

#pragma mark - Runtime Queries And Commands

- (BOOL)screenIsOn;
- (BOOL)wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion;

@end

NS_ASSUME_NONNULL_END
