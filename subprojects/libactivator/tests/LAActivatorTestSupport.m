//
//  LAActivatorTestSupport.m
//  libactivator
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorTestSupport.h"

#import "LAActivator+Private.h"
#import "LAActivatorIPC.h"
#import "LATestBuiltInActionRegistrySuite.h"
#import "LATestBuiltInMediaActionsSuite.h"
#import "LATestBuiltInRingerActionsSuite.h"
#import "LATestBuiltInURLActionsSuite.h"
#import "LATestDispatchSuite.h"
#import "LATestEnvironment.h"
#import "LATestEventSuite.h"
#import "LATestPersistenceSuite.h"
#import "LATestResourceSuite.h"
#import "LATestRuntimeDeviceSuite.h"
#import "LATestRuntimeInputSuite.h"
#import "LATestSpringBoardCoreSuite.h"
#import "LATestTouchActivitySuite.h"

@implementation LAActivatorTestSupport

+ (NSString *)userInfoProbeEventName {
    return @"libactivator.test.client-facade.user-info";
}

+ (NSString *)userInfoProbeListenerName {
    return @"libactivator.test.client-facade.user-info";
}

+ (NSDictionary *)handleCommandWithUserInfo:(NSDictionary *)userInfo activator:(LAActivator *)activator {
    NSString *command = [userInfo[LAActivatorIPCKeyTestingCommand] isKindOfClass:NSString.class]
                            ? userInfo[LAActivatorIPCKeyTestingCommand]
                            : nil;
    if ([command isEqualToString:LAActivatorIPCTestingCommandPing]) {
        return [self okReplyWithValue:@"ready"];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandCleanup]) {
        [LATestEnvironment cleanActivator:activator];
        [LATestEnvironment removeTestPlist];
        return [self okReplyWithValue:@"clean"];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRun]) {
        return [self okReplyWithValue:[self runStableTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRunRuntimeInput]) {
        return [self okReplyWithValue:[self runRuntimeInputTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRunDeviceRuntime]) {
        return [self okReplyWithValue:[self runDeviceRuntimeTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRuntimeState]) {
        return [self okReplyWithValue:[activator la_runtimeStateDebugDictionary]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandPrepareUserInfoProbe]) {
        NSString *eventName = [self userInfoProbeEventName];
        NSString *listenerName = [self userInfoProbeListenerName];
        LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
        LATestListener *listener = [[LATestListener alloc] init];
        listener.handlesReceivedEvents = YES;
        [activator registerEventDataSource:dataSource forEventName:eventName];
        [activator registerListener:listener forName:listenerName];
        return [self okReplyWithValue:@{
            LAActivatorIPCKeyEventName : eventName,
            LAActivatorIPCKeyListenerName : listenerName,
        }];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandUserInfoProbeResult]) {
        id<LAListener> listener = [activator listenerForName:[self userInfoProbeListenerName]];
        if (![listener isKindOfClass:LATestListener.class]) {
            return [self failureReply];
        }
        LATestListener *testListener = (LATestListener *)listener;
        return [self okReplyWithValue:@{
            @"ReceiveCount" : @(testListener.receiveCount),
            @"UserInfo" : testListener.lastReceivedUserInfo ?: @{},
        }];
    }
    return [self failureReply];
}

+ (NSDictionary *)okReplyWithValue:(id)value {
    if (value) {
        return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyValue : value};
    }
    return @{LAActivatorIPCKeyOK : @YES};
}

+ (NSDictionary *)failureReply {
    return @{LAActivatorIPCKeyOK : @NO};
}

+ (NSDictionary *)runStableTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [LATestEnvironment cleanActivator:activator];
    [LATestEnvironment removeTestPlist];
    [LATestEventSuite runWithRecorder:recorder];
    [LATestPersistenceSuite runWithRecorder:recorder];
    [LATestResourceSuite runWithRecorder:recorder];
    [LATestTouchActivitySuite runWithRecorder:recorder];
    [LATestSpringBoardCoreSuite runWithRecorder:recorder activator:activator];
    [LATestDispatchSuite runWithRecorder:recorder activator:activator];
    [LATestBuiltInActionRegistrySuite runWithRecorder:recorder activator:activator];
    [LATestBuiltInURLActionsSuite runWithRecorder:recorder activator:activator];
    [LATestBuiltInMediaActionsSuite runWithRecorder:recorder activator:activator];
    [LATestBuiltInRingerActionsSuite runWithRecorder:recorder activator:activator];
    [LATestEnvironment cleanActivator:activator];
    return [recorder resultDictionary];
}

+ (NSDictionary *)runRuntimeInputTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [LATestEnvironment cleanActivator:activator];
    [LATestEnvironment cleanRuntimeInputStateWithActivator:activator];
    [LATestRuntimeInputSuite runWithRecorder:recorder activator:activator];
    [LATestEnvironment cleanRuntimeInputStateWithActivator:activator];
    [LATestEnvironment cleanActivator:activator];
    return [recorder resultDictionary];
}

+ (NSDictionary *)runDeviceRuntimeTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [LATestEnvironment cleanActivator:activator];
    [LATestRuntimeDeviceSuite runWithRecorder:recorder activator:activator];
    [LATestEnvironment cleanActivator:activator];
    return [recorder resultDictionary];
}

@end

