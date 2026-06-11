//
//  LATSystemRingerStateResetter.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemRingerStateResetter.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

extern int BKSHIDServicesGetRingerState(void);

@interface UIApplication (RingerPrivate)
- (void)_updateRingerState:(int)ringerState
                 withVisuals:(BOOL)withVisuals
    updatePreferenceRegister:(BOOL)updatePreferenceRegister;
@end

@implementation LATSystemRingerStateResetter

- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName {
    if (![NSThread isMainThread]) {
        __block BOOL reset = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            reset = [self resetRingerStateForListenerName:listenerName];
        });
        return reset;
    }

    UIApplication *application = UIApplication.sharedApplication;
    SEL updateSelector = @selector(_updateRingerState:withVisuals:updatePreferenceRegister:);
    if (!application || ![application respondsToSelector:updateSelector]) {
        HBLogError(@"Unable to reset ringer state for system action %@ because SpringBoard does not support "
                   @"_updateRingerState:withVisuals:updatePreferenceRegister:",
                   listenerName ?: @"");
        return NO;
    }

    int ringerState = BKSHIDServicesGetRingerState();
    [application _updateRingerState:ringerState withVisuals:YES updatePreferenceRegister:NO];
    return YES;
}

@end
