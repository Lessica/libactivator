//
//  LATPowerStateEventSource.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATPowerStateEventSource : NSObject <LATEventSource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider NS_DESIGNATED_INITIALIZER;

// Main-queue confined. This source reads UIDevice battery state and submits events to the
// SpringBoard dispatch engine, so callers must start it from the SpringBoard main queue.
- (void)start;

@end

NS_ASSUME_NONNULL_END
