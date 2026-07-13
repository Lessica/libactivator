//
//  LATButtonEventSource.h
//  libactivator
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IOKitSPI.h"
#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"
#import "LATEventSourceIngress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATButtonEventSource : NSObject <LATEventSource, LATEventSourceHIDIngress>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                     assignmentQuerying:(id<LATEventAssignmentQuerying>)assignmentQuerying NS_DESIGNATED_INITIALIZER;

// Main-queue confined. This source observes hardware button HID events and submits Activator events
// without consuming the original system input.
- (void)start;
- (void)noteHIDEvent:(IOHIDEventRef)event;

@end

NS_ASSUME_NONNULL_END
