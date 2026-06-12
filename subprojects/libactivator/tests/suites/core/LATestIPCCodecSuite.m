//
//  LATestIPCCodecSuite.m
//  libactivator
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestIPCCodecSuite.h"

#import "LAIPC.h"
#import "LAIPCCodec.h"
#import "LATestEnvironment.h"

@implementation LATestIPCCodecSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"IPCCodec"];

    LAEvent *event = [LAEvent eventWithName:@"libactivator.test.ipc-codec" mode:LAEventModeApplication];
    event.handled = YES;
    event.userInfo = @{
        @"safe" : @"value",
        @"unsafe" : [[NSObject alloc] init],
        @"nested" : @{
            @"safe" : @42,
            @"unsafe" : [[NSObject alloc] init],
        },
        @"array" : @[ @"keep", [[NSObject alloc] init], @{@"safe" : @"nested"} ],
    };

    NSDictionary *eventDictionary = [LAIPCCodec userInfoWithEvent:event];
    NSDictionary *encodedUserInfo = [eventDictionary[LAIPCKeyEventUserInfo] isKindOfClass:NSDictionary.class]
                                        ? eventDictionary[LAIPCKeyEventUserInfo]
                                        : nil;
    [recorder expect:[eventDictionary[LAIPCKeyEventName] isEqualToString:event.name] &&
                     [eventDictionary[LAIPCKeyEventMode] isEqualToString:event.mode] &&
                     [eventDictionary[LAIPCKeyEventHandled] boolValue]
            caseName:@"event-encoding"
              reason:@"Event payload did not include name, mode, and handled state"];
    [recorder
          expect:[encodedUserInfo[@"safe"] isEqual:@"value"] && [encodedUserInfo[@"nested"][@"safe"] isEqual:@42] &&
                 [encodedUserInfo[@"array"] isEqualToArray:@[ @"keep", @{@"safe" : @"nested"} ]] &&
                 encodedUserInfo[@"unsafe"] == nil && encodedUserInfo[@"nested"][@"unsafe"] == nil
        caseName:@"event-user-info-plist-filter"
          reason:@"Event payload did not recursively filter non-property-list userInfo values"];

    LAEvent *decodedEvent = [LAIPCCodec eventWithUserInfo:eventDictionary];
    [recorder expect:[decodedEvent.name isEqualToString:event.name] && [decodedEvent.mode isEqualToString:event.mode] &&
                     decodedEvent.handled && [decodedEvent.userInfo[@"nested"][@"safe"] isEqual:@42]
            caseName:@"event-decoding"
              reason:@"Event payload did not decode back into LAEvent"];

    NSArray *malformedEventDictionaries = @[
        eventDictionary,
        @{LAIPCKeyEventMode : LAEventModeSpringBoard},
        @"invalid",
        @{LAIPCKeyEventName : @"libactivator.test.ipc-codec.second"},
    ];
    NSArray *decodedEvents = [LAIPCCodec eventsWithDictionaries:malformedEventDictionaries];
    [recorder expect:decodedEvents.count == 2 &&
                     [[decodedEvents.lastObject name] isEqualToString:@"libactivator.test.ipc-codec.second"]
            caseName:@"malformed-event-list-filter"
              reason:@"Malformed event dictionaries were not ignored"];

    NSDictionary *handledReply = [LAIPCCodec eventReplyWithEvent:event];
    [recorder expect:[handledReply[LAIPCKeyOK] boolValue] && [handledReply[LAIPCKeyEventHandled] boolValue]
            caseName:@"handled-reply"
              reason:@"Event reply did not carry handled state"];

    [recorder expect:[LAIPCCodec smallIconDataReplyWithData:nil scale:2.0][LAIPCKeyOK] &&
                         ![[LAIPCCodec smallIconDataReplyWithData:nil scale:2.0][LAIPCKeyOK] boolValue]
            caseName:@"empty-icon-reply-fails"
              reason:@"Empty icon data reply should fail safely"];
}

@end
