//
//  LATestBuiltInCameraActionsSuite.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInCameraActionsSuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInCameraActionsSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInCameraActions"];

    Class<LATestCameraActionListener> cameraActionClass =
        (Class<LATestCameraActionListener>)NSClassFromString(@"LATCameraActionListener");
    [recorder expect:cameraActionClass != Nil
            caseName:@"camera-action-class-available"
              reason:@"LATCameraActionListener class was not loaded in SpringBoard"];
    if (!cameraActionClass) {
        return;
    }

    NSDictionary<NSString *, NSString *> *expectedSelectors = @{
        @"libactivator.camera.invoke-shutter" : @"cameraShutterWithActivator:event:",
    };
    NSSet<NSString *> *supportedNames = [NSSet setWithArray:[cameraActionClass supportedListenerNames]];

    [recorder expect:supportedNames.count == expectedSelectors.count
            caseName:@"camera-action-allowlist-count"
              reason:@"Camera action allowlist did not match the expected command count"];
    for (NSString *listenerName in expectedSelectors) {
        NSString *expectedSelector = expectedSelectors[listenerName];
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        [recorder expect:[supportedNames containsObject:listenerName] && [activator hasListenerWithName:listenerName]
                caseName:[NSString stringWithFormat:@"camera-action-registered-%@", listenerName]
                  reason:@"Camera action allowlist or runtime registration is missing an expected listener name"];
        [recorder expect:[[cameraActionClass expectedSelectorForListenerName:listenerName]
                             isEqualToString:expectedSelector] &&
                         [selector isEqualToString:expectedSelector]
                caseName:[NSString stringWithFormat:@"camera-action-selector-%@", listenerName]
                  reason:@"Camera action selector mapping did not match bundled metadata"];
    }

    id<LATestCameraActionListener> cameraAction = [[(Class)cameraActionClass alloc] init];
    [recorder expect:[cameraAction listenerNameMatchesRequiredMetadata:@"libactivator.camera.invoke-shutter"
                                                             activator:activator]
            caseName:@"camera-action-valid-metadata-gated"
              reason:@"Camera action did not accept a listener name with matching selector metadata"];
    [recorder expect:![cameraAction listenerNameMatchesRequiredMetadata:@"libactivator.camera.invoke-shutter"
                                                              activator:nil]
            caseName:@"camera-action-missing-metadata-unhandled"
              reason:@"Camera action accepted a listener name without matching selector metadata"];

    LAEvent *unsupportedEvent = [LAEvent eventWithName:@"libactivator.test.built-in.camera"
                                                  mode:LAEventModeSpringBoard];
    [cameraAction activator:activator
               receiveEvent:unsupportedEvent
            forListenerName:@"libactivator.test.camera.unsupported"];
    [recorder expect:!unsupportedEvent.handled
            caseName:@"camera-action-unsupported-name-unhandled"
              reason:@"Unsupported camera action listener name consumed the event"];
}

@end
