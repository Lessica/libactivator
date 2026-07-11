//
//  LATFingerprintSensorEventSource.h
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IOKitSPI.h"
#import "LATEventSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATFingerprintSensorEventSource : NSObject <LATEventSource>

// Main-queue confined. This source observes Touch ID HID events and submits Activator events
// without consuming the original system input.

// Lifecycle
- (void)start;

// HID ingestion
- (void)noteHIDEvent:(IOHIDEventRef)event;

// Runtime coordination
- (void)noteDeviceUnlockedAtTimestamp:(NSTimeInterval)timestamp;

// Cross-source coordination
- (BOOL)consumePendingSinglePressForSlideInAtTimestamp:(NSTimeInterval)timestamp;

#if DEBUG
// Testing hooks
- (void)la_testingNoteTouchIDDown:(BOOL)touchDown
                    sequenceState:(NSInteger)sequenceState
                        timestamp:(NSTimeInterval)timestamp;
- (void)la_testingResolvePendingSinglePress;
- (void)la_testingSendShortHoldIfNeeded;
- (void)la_testingSendLongHoldIfNeeded;
#endif

@end

NS_ASSUME_NONNULL_END
