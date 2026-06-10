//
//  LATestResourceSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestResourceSuite.h"

#import "LATestEnvironment.h"

@implementation LATestResourceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"Resources"];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    LAActivatorResourceManager *resourceManager = LAActivatorResourceManager.sharedManager;

    NSString *eventName = @"libactivator.test.resource.capability";
    NSString *eventPath = [[resourceManager eventsDirectoryPath] stringByAppendingPathComponent:eventName];
    [fileManager removeItemAtPath:eventPath error:nil];
    [fileManager createDirectoryAtPath:eventPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *eventInfo = @{
        @"title" : @"Unsupported Test Event",
        @"group" : @"Testing",
        @"required-capabilities" : @[ @"libactivator.test.missing-capability" ],
    };
    [eventInfo writeToFile:[eventPath stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
    [recorder expect:![resourceManager.availableEventNames containsObject:eventName] &&
                     [resourceManager eventInfoDictionaryForName:eventName] == nil
            caseName:@"required-capability-filter"
              reason:@"Unsupported resource capability should hide event metadata"];

    [fileManager removeItemAtPath:eventPath error:nil];

    NSArray *smallIcons = [resourceManager infoDictionaryValueOfKey:@"small-icons"
                                                    forListenerName:@"libactivator.settings.wifi"];
    [recorder expect:[smallIcons isKindOfClass:NSArray.class] && smallIcons.count > 0
            caseName:@"small-icons-metadata"
              reason:@"1.9.13 bundled listener small icon metadata was not read"];

    NSString *resourceRootPath = @"/var/mobile/Library/Caches/libactivator-resource-path-test.dat";
    NSString *resourcePath = jbroot(resourceRootPath);
    NSData *resourceData = [@"libactivator-resource-path-test" dataUsingEncoding:NSUTF8StringEncoding];
    [resourceData writeToFile:resourcePath atomically:YES];
    NSString *resolvedPath = [resourceManager resolvedPathForResourcePath:resourceRootPath];
    NSData *resolvedData = resolvedPath.length > 0 ? [NSData dataWithContentsOfFile:resolvedPath] : nil;
    [recorder expect:[resolvedPath isEqualToString:resourcePath] && [resolvedData isEqualToData:resourceData]
            caseName:@"absolute-path-resolution"
              reason:@"Absolute resource path did not resolve through jbroot before the original path"];

    [fileManager removeItemAtPath:resourcePath error:nil];
}

@end

