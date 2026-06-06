//
//  LAActivatorRuntimeStateProvider.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorRuntimeStateProvider.h"

@implementation LAActivatorRuntimeStateProvider {
    BOOL _runningInsideSpringBoard;
}

- (instancetype)initWithSpringBoardRole:(BOOL)runningInsideSpringBoard {
    self = [super init];
    if (self) {
        _runningInsideSpringBoard = runningInsideSpringBoard;
    }
    return self;
}

- (NSString *)currentEventMode {
    return _runningInsideSpringBoard ? LAEventModeSpringBoard : LAEventModeApplication;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    return LAEventModeApplication;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return NO;
}

- (NSString *)displayIdentifierForCurrentApplication {
    return [[NSBundle mainBundle] bundleIdentifier];
}

@end
