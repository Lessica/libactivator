//
//  LATestEventSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSuite.h"

#import "LATestEnvironment.h"

@implementation LATestEventSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"LAEvent"];

    LAEvent *event = [LAEvent eventWithName:@"libactivator.test.event" mode:nil];
    event.handled = YES;
    event.userInfo = @{@"Key" : @"Value"};
    [recorder expect:[event.name isEqualToString:@"libactivator.test.event"]
            caseName:@"factory-name"
              reason:@"Name mismatch"];
    [recorder expect:event.mode == nil caseName:@"nil-mode" reason:@"Nil mode was not preserved"];
    [recorder expect:event.handled caseName:@"handled" reason:@"Handled flag mismatch"];
    [recorder expect:[event.userInfo[@"Key"] isEqualToString:@"Value"]
            caseName:@"user-info"
              reason:@"User info mismatch"];

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:NO error:&archiveError];
    NSError *unarchiveError = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&unarchiveError];
    unarchiver.requiresSecureCoding = NO;
    LAEvent *decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    [recorder expect:data.length > 0 && archiveError == nil && unarchiveError == nil &&
                     [decoded.name isEqualToString:event.name] && decoded.handled
            caseName:@"nscoding"
              reason:@"NSCoding round-trip failed"];
}

@end
