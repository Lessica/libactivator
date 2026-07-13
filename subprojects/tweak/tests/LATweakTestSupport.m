//
//  LATweakTestSupport.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATweakTestSupport.h"

#if LIBACTIVATOR_TEST_SUPPORT

#import "LAActivatorTestRegistry.h"
#import "LATestBuiltInCameraActionsSuite.h"
#import "LATestBuiltInComposeActionsSuite.h"
#import "LATestBuiltInDynamicApplicationListenersSuite.h"
#import "LATestBuiltInEventSourceCompositionSuite.h"
#import "LATestBuiltInHardwareActionsSuite.h"
#import "LATestBuiltInListenerCompositionSuite.h"
#import "LATestBuiltInSystemActionsSuite.h"
#import "LATestBuiltInTelephonyActionsSuite.h"
#import "LATestBuiltInURLActionsSuite.h"
#import "LATestEventDefinitionRegistrySuite.h"
#import "LATestEventSourceAcquisitionSuite.h"
#import "LATestEventSourceRegistrySuite.h"
#import "LATestGestureRecognizerSuite.h"
#import "LATestRuntimeDeviceSuite.h"
#import "LATweakTestEnvironment.h"

#import <Activator/Activator.h>

static NSString *const LATweakTestGroupIdentifier = @"tweak";

@implementation LATweakTestSupport

+ (BOOL)registerTests {
    return [LAActivatorTestRegistry registerGroupWithIdentifier:LATweakTestGroupIdentifier
        cleanupBlock:^(LAActivator *registeredActivator) {
            [LATweakTestEnvironment cleanActivator:registeredActivator];
        }
        stableTestsBlock:^(LATestRecorder *recorder, LAActivator *registeredActivator) {
            [LATestBuiltInListenerCompositionSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInURLActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInHardwareActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInSystemActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInCameraActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInComposeActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInTelephonyActionsSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInDynamicApplicationListenersSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestEventDefinitionRegistrySuite runWithRecorder:recorder activator:registeredActivator];
            [LATestEventSourceRegistrySuite runWithRecorder:recorder activator:registeredActivator];
            [LATestBuiltInEventSourceCompositionSuite runWithRecorder:recorder activator:registeredActivator];
            [LATestGestureRecognizerSuite runWithRecorder:recorder];
            [LATestEventSourceAcquisitionSuite runWithRecorder:recorder activator:registeredActivator];
        }
        deviceRuntimeTestsBlock:^(LATestRecorder *recorder, LAActivator *registeredActivator) {
            [LATestRuntimeDeviceSuite runWithRecorder:recorder activator:registeredActivator];
        }];
}

@end

#endif
