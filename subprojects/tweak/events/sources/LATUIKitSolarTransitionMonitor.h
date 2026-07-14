//
//  LATUIKitSolarTransitionMonitor.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LATSolarTransitionHandler)(BOOL darkScheduleActive);

@protocol LATSolarTransitionMonitoring <NSObject>

- (BOOL)startWithTransitionHandler:(LATSolarTransitionHandler)transitionHandler;
- (void)invalidate;

@end

@interface LATUIKitSolarTransitionMonitor : NSObject <LATSolarTransitionMonitoring>

@property(class, nonatomic, assign, readonly, getter=isAvailable) BOOL available;

@end

NS_ASSUME_NONNULL_END
