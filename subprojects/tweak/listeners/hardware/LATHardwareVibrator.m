//
//  LATHardwareVibrator.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "hardware/LATHardwareVibrator.h"

#import <AudioToolbox/AudioToolbox.h>

@implementation LATHardwareVibrator

- (BOOL)vibrateForListenerName:(NSString *)listenerName {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    return YES;
}

@end
