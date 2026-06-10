//
//  LATestSpringBoardTestClient.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestSpringBoardTestClient.h"

#import "LAActivatorIPC.h"

#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LATestSpringBoardTestClient ()
@property(nonatomic, strong) CPDistributedMessagingCenter *center;
@end

@implementation LATestSpringBoardTestClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LAActivatorIPCServerName];
    }
    return self;
}

- (BOOL)waitForServer {
    for (NSInteger attempt = 0; attempt < 60; attempt++) {
        NSDictionary *reply = [self sendCommand:LAActivatorIPCTestingCommandPing];
        if ([reply[LAActivatorIPCKeyOK] boolValue]) {
            printf("[tests] SpringBoard test server is ready\n");
            fflush(stdout);
            return YES;
        }
        if (attempt == 0 || (attempt + 1) % 5 == 0) {
            printf("[tests] Still waiting for SpringBoard test server (%ld/60)\n", (long)(attempt + 1));
            fflush(stdout);
        }
        [NSThread sleepForTimeInterval:1.0];
    }
    return NO;
}

- (NSDictionary *)sendCommand:(NSString *)command {
    NSDictionary *reply =
        [self.center sendMessageAndReceiveReplyName:LAActivatorIPCMessageTesting
                                           userInfo:@{LAActivatorIPCKeyTestingCommand : command ?: @""}];
    return [reply isKindOfClass:NSDictionary.class] ? reply : @{};
}

@end
