//
//  LATestResourceSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestResourceSuite.h"

#import "LATestEnvironment.h"

@interface LATestResourceSuite ()
+ (NSDictionary<NSString *, NSDictionary *> *)bundledListenerMetadataWithResourceManager:
    (LAResourceManager *)resourceManager;
+ (BOOL)allBundledListenersHaveActionMetadata:(NSDictionary<NSString *, NSDictionary *> *)listeners;
+ (BOOL)bundledListenerSelectorsHaveOnlyExpectedDuplicates:(NSDictionary<NSString *, NSDictionary *> *)listeners;
@end

@implementation LATestResourceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"Resources"];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    LAResourceManager *resourceManager = LAResourceManager.sharedManager;

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

    NSDictionary<NSString *, NSDictionary *> *bundledListeners =
        [self bundledListenerMetadataWithResourceManager:resourceManager];
    [recorder expect:bundledListeners.count > 0 && [self allBundledListenersHaveActionMetadata:bundledListeners]
            caseName:@"bundled-listeners-have-action-metadata"
              reason:@"Bundled listener metadata must contain selector, url, or urls"];
    [recorder expect:[self bundledListenerSelectorsHaveOnlyExpectedDuplicates:bundledListeners]
            caseName:@"bundled-listener-selector-duplicates"
              reason:@"Bundled listener selector metadata has an unexpected duplicate"];

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

+ (NSDictionary<NSString *, NSDictionary *> *)bundledListenerMetadataWithResourceManager:
    (LAResourceManager *)resourceManager {
    NSString *path = [[resourceManager listenersDirectoryPath] stringByAppendingPathComponent:@"bundled.plist"];
    NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:path];
    return [metadata isKindOfClass:NSDictionary.class] ? metadata : @{};
}

+ (BOOL)allBundledListenersHaveActionMetadata:(NSDictionary<NSString *, NSDictionary *> *)listeners {
    for (NSString *listenerName in listeners) {
        NSDictionary *metadata = listeners[listenerName];
        if (![metadata isKindOfClass:NSDictionary.class]) {
            return NO;
        }
        BOOL hasSelector = [metadata[@"selector"] isKindOfClass:NSString.class] && [metadata[@"selector"] length] > 0;
        BOOL hasURL = [metadata[@"url"] isKindOfClass:NSString.class] && [metadata[@"url"] length] > 0;
        BOOL hasURLs = [metadata[@"urls"] isKindOfClass:NSArray.class] && [metadata[@"urls"] count] > 0;
        if (!hasSelector && !hasURL && !hasURLs) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)bundledListenerSelectorsHaveOnlyExpectedDuplicates:(NSDictionary<NSString *, NSDictionary *> *)listeners {
    NSSet<NSString *> *allowedDuplicateSelectors = [NSSet setWithArray:@[
        @"openURLWithActivator:event:listenerName:",
        @"tapticWithActivator:event:listenerName:",
    ]];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *listenerNamesBySelector = [NSMutableDictionary new];
    for (NSString *listenerName in listeners) {
        NSDictionary *metadata = listeners[listenerName];
        NSString *selector = [metadata[@"selector"] isKindOfClass:NSString.class] ? metadata[@"selector"] : nil;
        if (selector.length == 0) {
            continue;
        }
        NSMutableArray<NSString *> *listenerNames = listenerNamesBySelector[selector];
        if (!listenerNames) {
            listenerNames = [NSMutableArray new];
            listenerNamesBySelector[selector] = listenerNames;
        }
        [listenerNames addObject:listenerName];
    }

    for (NSString *selector in listenerNamesBySelector) {
        NSArray<NSString *> *listenerNames = listenerNamesBySelector[selector];
        if (listenerNames.count > 1 && ![allowedDuplicateSelectors containsObject:selector]) {
            return NO;
        }
    }
    return YES;
}

@end
