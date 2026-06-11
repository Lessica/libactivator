//
//  LATestSpringBoardClient.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestSpringBoardClient.h"

#import "LAIPC.h"

#import <AppSupport/CPDistributedMessagingCenter.h>

@interface LATestSpringBoardClient ()
@property(nonatomic, strong) CPDistributedMessagingCenter *center;
@end

@implementation LATestSpringBoardClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = [CPDistributedMessagingCenter centerNamed:LAIPCServerName];
    }
    return self;
}

- (BOOL)waitForServer {
    for (NSInteger attempt = 0; attempt < 60; attempt++) {
        NSDictionary *reply = [self sendCommand:LAIPCTestingCommandPing];
        if ([reply[LAIPCKeyOK] boolValue]) {
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
    NSDictionary *reply = [self.center sendMessageAndReceiveReplyName:LAIPCMessageTesting
                                                             userInfo:@{LAIPCKeyTestingCommand : command ?: @""}];
    return [reply isKindOfClass:NSDictionary.class] ? reply : @{};
}

@end
