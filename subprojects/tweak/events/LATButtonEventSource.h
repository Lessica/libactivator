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

NS_ASSUME_NONNULL_BEGIN

@interface LATButtonEventSource : NSObject <LATEventSource>

// Main-queue confined. This source observes hardware button HID events and submits Activator events
// without consuming the original system input.
- (void)start;
- (void)noteHIDEvent:(IOHIDEventRef)event;

@end

NS_ASSUME_NONNULL_END
