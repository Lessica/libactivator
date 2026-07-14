//
//  LATUIKitSolarTransitionMonitor.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATUIKitSolarTransitionMonitor.h"

#import "LAQueueAssertions.h"

#import <objc/runtime.h>

@interface _UISunScheduleController : NSObject

@property(nonatomic, assign, readonly, getter=isInScheduleTime) BOOL inScheduleTime;

- (void)addObserver:(id)observer changeHandler:(dispatch_block_t)changeHandler;
- (void)removeObserver:(id)observer;

@end

@interface UIUserInterfaceStyleArbiter : NSObject

+ (instancetype)sharedInstance;

@end

@interface LATUIKitSolarTransitionMonitor ()

@property(nonatomic, strong) _UISunScheduleController *scheduleController;
@property(nonatomic, copy) LATSolarTransitionHandler transitionHandler;
@property(nonatomic, assign) BOOL darkScheduleActive;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

@end

@implementation LATUIKitSolarTransitionMonitor

+ (BOOL)isAvailable {
    return NSClassFromString(@"_UISunScheduleController") != Nil;
}

- (void)dealloc {
    if (!self.isInvalidated) {
        [self invalidate];
    }
}

- (BOOL)startWithTransitionHandler:(LATSolarTransitionHandler)transitionHandler {
    LAAssertMainQueue();
    NSParameterAssert(transitionHandler);
    if (self.isInvalidated) {
        return NO;
    }
    if (self.isStarted) {
        return YES;
    }

    UIUserInterfaceStyleArbiter *styleArbiter = [NSClassFromString(@"UIUserInterfaceStyleArbiter") sharedInstance];
    Ivar scheduleControllerIvar = class_getInstanceVariable(styleArbiter.class, "_sunScheduleController");
    _UISunScheduleController *scheduleController =
        scheduleControllerIvar ? object_getIvar(styleArbiter, scheduleControllerIvar) : nil;
    if (!scheduleController) {
        scheduleController = [[NSClassFromString(@"_UISunScheduleController") alloc] init];
    }
    if (!scheduleController) {
        return NO;
    }

    self.scheduleController = scheduleController;
    self.transitionHandler = transitionHandler;
    self.darkScheduleActive = scheduleController.isInScheduleTime;
    self.started = YES;

    __weak typeof(self) weakSelf = self;
    [scheduleController addObserver:self
                      changeHandler:^{
                          [weakSelf scheduleStateDidChange];
                      }];
    return YES;
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self.scheduleController removeObserver:self];
    self.scheduleController = nil;
    self.transitionHandler = nil;
}

- (void)scheduleStateDidChange {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated) {
        return;
    }

    BOOL darkScheduleActive = self.scheduleController.isInScheduleTime;
    if (darkScheduleActive == self.darkScheduleActive) {
        return;
    }

    self.darkScheduleActive = darkScheduleActive;
    self.transitionHandler(darkScheduleActive);
}

@end
