//
//  LATSystemHapticFeedbackController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemHapticFeedbackController.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@implementation LATSystemHapticFeedbackController

- (BOOL)performHapticFeedbackType:(LATSystemHapticFeedbackType)feedbackType listenerName:(NSString *)listenerName {
    switch (feedbackType) {
    case LATSystemHapticFeedbackTypeFlick:
        [self performImpactHapticFeedbackStyle:UIImpactFeedbackStyleHeavy listenerName:listenerName];
        break;
    case LATSystemHapticFeedbackTypeTap:
        [self performImpactHapticFeedbackStyle:UIImpactFeedbackStyleLight listenerName:listenerName];
        break;
    case LATSystemHapticFeedbackTypeQuirk:
        [self performNotificationHapticFeedbackType:UINotificationFeedbackTypeSuccess listenerName:listenerName];
        break;
    default:
        HBLogError(@"Unknown haptic feedback type %ld for system action %@", (long)feedbackType, listenerName ?: @"");
        break;
    }
    return YES;
}

- (void)performImpactHapticFeedbackStyle:(NSInteger)style listenerName:(NSString *)listenerName {
    Class generatorClass = NSClassFromString(@"UIImpactFeedbackGenerator");
    if (!generatorClass) {
        HBLogError(@"UIImpactFeedbackGenerator is unavailable for system action %@", listenerName ?: @"");
        return;
    }

    id generator = [[generatorClass alloc] initWithStyle:style];
    if ([generator respondsToSelector:@selector(prepare)]) {
        [generator prepare];
    }
    if ([generator respondsToSelector:@selector(impactOccurred)]) {
        [generator impactOccurred];
    } else {
        HBLogError(@"UIImpactFeedbackGenerator cannot trigger feedback for system action %@", listenerName ?: @"");
    }
}

- (void)performNotificationHapticFeedbackType:(NSInteger)type listenerName:(NSString *)listenerName {
    Class generatorClass = NSClassFromString(@"UINotificationFeedbackGenerator");
    if (!generatorClass) {
        HBLogError(@"UINotificationFeedbackGenerator is unavailable for system action %@", listenerName ?: @"");
        return;
    }

    id generator = [[generatorClass alloc] init];
    if ([generator respondsToSelector:@selector(prepare)]) {
        [generator prepare];
    }
    if ([generator respondsToSelector:@selector(notificationOccurred:)]) {
        [generator notificationOccurred:type];
    } else {
        HBLogError(@"UINotificationFeedbackGenerator cannot trigger feedback for system action %@",
                   listenerName ?: @"");
    }
}

@end
