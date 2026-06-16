//
//  LATSystemPreviousApplicationController.m
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemPreviousApplicationController.h"

#import "LATApplicationLauncher.h"
#import "LATRuntimeStateSource.h"

#import <HBLog.h>

@interface LATSystemPreviousApplicationController ()
@property(nonatomic, strong) LATApplicationLauncher *applicationLauncher;
@property(nonatomic, weak, nullable) LATRuntimeStateSource *runtimeStateSource;
@end

@implementation LATSystemPreviousApplicationController

- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource {
    NSParameterAssert(applicationLauncher);

    self = [super init];
    if (self) {
        _applicationLauncher = applicationLauncher;
        _runtimeStateSource = runtimeStateSource;
    }
    return self;
}

- (BOOL)launchPreviousApplicationForListenerName:(NSString *)listenerName {
    LATRuntimeStateSource *runtimeStateSource = self.runtimeStateSource;
    if (!runtimeStateSource) {
        HBLogError(@"Unable to launch previous application for system action %@ because the runtime state source is "
                   @"unavailable",
                   listenerName ?: @"");
        return NO;
    }

    NSString *displayIdentifier = [runtimeStateSource displayIdentifierForPreviousApplication];
    if (displayIdentifier.length == 0) {
        HBLogWarn(@"No previous application is available for system action %@", listenerName ?: @"");
        return NO;
    }

    if (![self.applicationLauncher enqueueLaunchApplicationWithIdentifier:displayIdentifier unlockDevice:YES]) {
        HBLogError(@"Unable to enqueue previous application %@ for system action %@", displayIdentifier,
                   listenerName ?: @"");
        return NO;
    }
    return YES;
}

@end
