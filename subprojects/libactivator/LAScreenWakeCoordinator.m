//
//  LAScreenWakeCoordinator.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAScreenWakeCoordinator.h"

#import "LAActivator+Private.h"
#import "LAHIDPowerButtonSender.h"

#import <HBLog.h>
#import <notify.h>

static const NSTimeInterval LAScreenWakeFallbackDelay = 2.0;
static const char *LAScreenWakeBlankedScreenNotification = "com.apple.springboard.hasBlankedScreen";

@interface LAScreenWakeCoordinator ()
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) LAHIDPowerButtonSender *powerButtonSender;
@property(nonatomic, assign) int notifyToken;
@property(nonatomic, assign) BOOL wakeRequestInFlight;
@property(nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingCompletions;
@end

@implementation LAScreenWakeCoordinator

- (instancetype)init {
    self = [super init];
    if (self) {
        _powerButtonSender = [[LAHIDPowerButtonSender alloc] init];
        _pendingCompletions = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)startObservingScreenStateWithActivator:(LAActivator *)activator {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activator = activator;
        [self startObservingScreenStateIfNeeded];
    });
}

- (BOOL)wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion {
    if (!completion) {
        HBLogWarn(@"Ignoring screen wake request without completion: %@", reason ?: @"");
        return NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self screenIsOn]) {
            completion();
            return;
        }

        [self.pendingCompletions addObject:[completion copy]];
        [self startObservingScreenStateIfNeeded];
        if (self.pendingCompletions.count == 0) {
            return;
        }
        [self requestPowerButtonWakeIfNeededForReason:reason];
    });

    return YES;
}

#pragma mark - Private

- (void)startObservingScreenStateIfNeeded {
    if (self.notifyToken != 0) {
        return;
    }

    int token = 0;
    int status = notify_register_dispatch(LAScreenWakeBlankedScreenNotification, &token, dispatch_get_main_queue(),
                                          ^(int deliveredToken) {
                                              [self handleBlankedScreenNotificationWithToken:deliveredToken];
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogWarn(@"Unable to observe screen power state: %d", status);
        return;
    }

    self.notifyToken = token;
    [self handleBlankedScreenNotificationWithToken:token];
}

- (void)requestPowerButtonWakeIfNeededForReason:(NSString *)reason {
    if (self.wakeRequestInFlight) {
        return;
    }

    self.wakeRequestInFlight = YES;
    if (![self.powerButtonSender sendPowerButtonPressForReason:reason]) {
        [self resetWakeRequest];
        [self.pendingCompletions removeAllObjects];
        HBLogWarn(@"Unable to press power button for screen wake: %@", reason ?: @"");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LAScreenWakeFallbackDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       if (!self.wakeRequestInFlight) {
                           return;
                       }
                       if (![self screenIsOn]) {
                           HBLogWarn(@"Screen did not turn on before wake request timed out");
                           [self resetWakeRequest];
                           [self.pendingCompletions removeAllObjects];
                           return;
                       }

                       [self completeScreenWake];
                   });
}

- (void)handleBlankedScreenNotificationWithToken:(int)token {
    uint64_t blanked = 1;
    notify_get_state(token, &blanked);
    [self.activator la_noteScreenBlanked:blanked != 0];
    if (blanked != 0) {
        return;
    }

    [self completeScreenWake];
}

- (void)completeScreenWake {
    NSArray<dispatch_block_t> *completions = [self.pendingCompletions copy];
    [self.pendingCompletions removeAllObjects];
    [self resetWakeRequest];

    for (dispatch_block_t completion in completions) {
        completion();
    }
}

- (void)resetWakeRequest {
    self.wakeRequestInFlight = NO;
}

- (BOOL)screenIsOn {
    return self.activator ? [self.activator la_screenIsOn] : YES;
}

@end
