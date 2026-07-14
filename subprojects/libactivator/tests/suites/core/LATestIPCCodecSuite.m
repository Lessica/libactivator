//
//  LATestIPCCodecSuite.m
//  libactivator
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestIPCCodecSuite.h"

#import "LAActivator+Private.h"
#import "LAIPC.h"
#import "LAIPCCodec.h"
#import "LATestEnvironment.h"
#import "LATestListener.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>
#import <math.h>

@interface LAIPCServer (LATestIPCCodecSuite)
- (NSDictionary *)handleMessageNamed:(NSString *)messageName withUserInfo:(NSDictionary *)userInfo;
@end

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
    [recorder expect:[encodedUserInfo[@"safe"] isEqual:@"value"] && [encodedUserInfo[@"nested"][@"safe"] isEqual:@42] &&
                     [encodedUserInfo[@"array"] isEqualToArray:@[ @"keep", @{@"safe" : @"nested"} ]] &&
                     encodedUserInfo[@"unsafe"] == nil && encodedUserInfo[@"nested"][@"unsafe"] == nil
            caseName:@"event-user-info-plist-filter"
              reason:@"Event payload did not recursively filter non-property-list userInfo values"];

    [recorder expect:[LAIPCCodec isPropertyListValue:@{@"safe" : @[ @"value", @42 ]}]
            caseName:@"valid-property-list-check"
              reason:@"Valid property-list payload was rejected"];

    NSMutableString *mutableString = [@"Original" mutableCopy];
    NSMutableData *mutableData = [NSMutableData dataWithBytes:"a" length:1];
    NSString *copiedString = [LAIPCCodec propertyListValue:mutableString];
    NSData *copiedData = [LAIPCCodec propertyListValue:mutableData];
    [mutableString appendString:@" Changed"];
    [mutableData appendBytes:"b" length:1];
    [recorder expect:[copiedString isEqualToString:@"Original"] && copiedData.length == 1
            caseName:@"property-list-scalars-detached"
              reason:@"Serialized scalar values retained caller-owned mutable storage"];

    [recorder expect:[[LAIPCCodec numberInUserInfo:@{@"number" : @1} forKey:@"number"] isEqual:@1] &&
                     [LAIPCCodec numberInUserInfo:@{@"number" : @[]} forKey:@"number"] == nil
            caseName:@"typed-number-decoding"
              reason:@"IPC number decoding accepted a non-number value"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-circular-container"
    NSMutableDictionary *cyclicDictionary = [@{@"safe" : @"value"} mutableCopy];
    cyclicDictionary[@"cycle"] = cyclicDictionary;
    NSMutableArray *cyclicArray = [NSMutableArray arrayWithObject:@"safe"];
    [cyclicArray addObject:cyclicArray];
#pragma clang diagnostic pop

    NSDictionary *sanitizedCyclicDictionary = [LAIPCCodec propertyListValue:cyclicDictionary];
    [recorder expect:[sanitizedCyclicDictionary[@"safe"] isEqual:@"value"] && sanitizedCyclicDictionary[@"cycle"] == nil
            caseName:@"cyclic-dictionary-filter"
              reason:@"Cyclic dictionary payload was not filtered safely"];

    NSArray *sanitizedCyclicArray = [LAIPCCodec propertyListValue:cyclicArray];
    [recorder expect:[sanitizedCyclicArray isEqualToArray:@[ @"safe" ]]
            caseName:@"cyclic-array-filter"
              reason:@"Cyclic array payload was not filtered safely"];

    [recorder
          expect:![LAIPCCodec isPropertyListValue:cyclicDictionary] && ![LAIPCCodec isPropertyListValue:cyclicArray] &&
                 ![LAIPCCodec isPropertyListValue:@{@"unsafe" : [[NSObject alloc] init]}]
        caseName:@"invalid-property-list-check"
          reason:@"Invalid property-list payload was not rejected safely"];

    LAEvent *decodedEvent = [LAIPCCodec eventWithUserInfo:eventDictionary];
    [recorder expect:[decodedEvent.name isEqualToString:event.name] && [decodedEvent.mode isEqualToString:event.mode] &&
                     decodedEvent.handled && [decodedEvent.userInfo[@"nested"][@"safe"] isEqual:@42]
            caseName:@"event-decoding"
              reason:@"Event payload did not decode back into LAEvent"];

    [recorder expect:[LAIPCCodec eventWithUserInfo:@{
                         LAIPCKeyEventName : @"libactivator.test.ipc-codec.invalid-handled",
                         LAIPCKeyEventHandled : @[],
                     }] == nil
            caseName:@"malformed-event-handled-rejected"
              reason:@"Event decoding accepted a non-number handled value"];
    [recorder expect:[LAIPCCodec eventWithUserInfo:@{
                         LAIPCKeyEventName : @"libactivator.test.ipc-codec.invalid-mode",
                         LAIPCKeyEventMode : @[],
                     }] == nil &&
                     [LAIPCCodec eventWithUserInfo:@{
                         LAIPCKeyEventName : @"libactivator.test.ipc-codec.invalid-user-info",
                         LAIPCKeyEventUserInfo : @[],
                     }] == nil
            caseName:@"malformed-optional-event-fields-rejected"
              reason:@"Event decoding treated malformed optional fields as absent"];

    LAActivator *serverActivator = LAActivator.sharedInstance;
    NSString *serverPreferenceKey = @"libactivator.tests.invalid-server-preference";
    [serverActivator _setObject:@"Original" forPreference:serverPreferenceKey];
    LAIPCServer *server = [[LAIPCServer alloc] initWithActivator:serverActivator];
    NSArray *malformedRequestReplies = @[
        [server handleMessageNamed:LAIPCMessageSetApplicationBlacklisted
                      withUserInfo:@{
                          LAIPCKeyDisplayIdentifier : @"com.example.Invalid",
                          LAIPCKeyBlacklisted : @[],
                      }],
        [server handleMessageNamed:LAIPCMessageSetApplicationAccessibilityEnabled
                      withUserInfo:@{LAIPCKeyApplicationAccessibilityEnabled : @{}}],
        [server handleMessageNamed:LAIPCMessageListenerSmallIconData
                      withUserInfo:@{LAIPCKeyListenerName : @"libactivator.test.listener", LAIPCKeyScale : @[]}],
        [server handleMessageNamed:LAIPCMessageSetPreferenceValue
                      withUserInfo:@{
                          LAIPCKeyPreferenceKey : serverPreferenceKey,
                          LAIPCKeyPreferenceValue : @{@"Unsafe" : [[NSObject alloc] init]},
                      }],
    ];
    BOOL rejectedMalformedRequests = YES;
    for (NSDictionary *reply in malformedRequestReplies) {
        NSNumber *ok = [LAIPCCodec numberInUserInfo:reply forKey:LAIPCKeyOK];
        if (!ok || ok.boolValue) {
            rejectedMalformedRequests = NO;
            break;
        }
    }
    [recorder expect:rejectedMalformedRequests &&
                     [[serverActivator _getObjectForPreference:serverPreferenceKey] isEqual:@"Original"]
            caseName:@"malformed-server-requests-rejected"
              reason:@"IPC server accepted or partially applied a malformed request"];
    [serverActivator _setObject:nil forPreference:serverPreferenceKey];

    NSString *backgroundListenerName = @"libactivator.test.listener.a";
    LATestListener *backgroundListener = [[LATestListener alloc] init];
    __block BOOL metadataCallbackWasOnMainThread = NO;
    backgroundListener.metadataHandler = ^{
        metadataCallbackWasOnMainThread = NSThread.isMainThread;
    };
    [serverActivator registerListener:backgroundListener forName:backgroundListenerName];
    __block NSDictionary *backgroundReply = nil;
    __block BOOL backgroundRequestCompleted = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSDictionary *reply = [server handleMessageNamed:LAIPCMessageListenerIsCompatibleWithMode
                                            withUserInfo:@{
                                                LAIPCKeyListenerName : backgroundListenerName,
                                                LAIPCKeyEventMode : LAEventModeSpringBoard,
                                            }];
        dispatch_async(dispatch_get_main_queue(), ^{
            backgroundReply = reply;
            backgroundRequestCompleted = YES;
        });
    });
    BOOL backgroundRequestReturned = [LATestEnvironment
        waitUntilTrue:^BOOL {
            return backgroundRequestCompleted;
        }
              timeout:1.0];
    [recorder expect:backgroundRequestReturned && metadataCallbackWasOnMainThread &&
                     [backgroundReply[LAIPCKeyOK] boolValue] && [backgroundReply[LAIPCKeyValue] boolValue]
            caseName:@"ipc-server-confines-callbacks-to-main-thread"
              reason:@"A background IPC request did not complete through the main-thread callback boundary"];
    [serverActivator unregisterListenerWithName:backgroundListenerName];

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
    NSData *iconData = [NSData dataWithBytes:"a" length:1];
    NSDictionary *zeroScaleReply = [LAIPCCodec smallIconDataReplyWithData:iconData scale:0.0];
    NSDictionary *nonfiniteScaleReply = [LAIPCCodec smallIconDataReplyWithData:iconData scale:NAN];
    [recorder expect:![zeroScaleReply[LAIPCKeyOK] boolValue] && ![nonfiniteScaleReply[LAIPCKeyOK] boolValue]
            caseName:@"invalid-icon-scale-reply-fails"
              reason:@"Icon replies should reject non-positive or non-finite scales"];
}

@end
