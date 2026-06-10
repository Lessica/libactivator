//
//  LATURLActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATURLActionListener.h"

#import <UIKit/UIKit.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options error:(NSError **)error;
@end

#if LA_TESTING
static LATURLActionOpenHandler LATTestingOpenHandler;
static NSURL *LATTestingLastOpenedURL;
static NSString *LATTestingLastOpenedListenerName;
static NSMutableDictionary *LATTestingURLMetadata;
#endif

@implementation LATURLActionListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    NSString *urlString = [self urlStringForListenerName:listenerName activator:activator];
    if (urlString.length == 0) {
        NSLog(@"libactivator: URL action %@ has no URL metadata", listenerName ?: @"");
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (url.scheme.length == 0) {
        NSLog(@"libactivator: URL action %@ has invalid URL metadata: %@", listenerName ?: @"", urlString);
        return;
    }

    if ([self openURL:url listenerName:listenerName]) {
        event.handled = YES;
    }
}

- (NSString *)urlStringForListenerName:(NSString *)listenerName activator:(LAActivator *)activator {
    if (listenerName.length == 0) {
        return nil;
    }

#if LA_TESTING
    NSDictionary *testingMetadata = LATTestingURLMetadata[listenerName];
    if (testingMetadata) {
        id testingURL = testingMetadata[@"url"];
        if ([testingURL isKindOfClass:NSString.class] && [testingURL length] > 0) {
            return testingURL;
        }
        return [self urlStringInURLsValue:testingMetadata[@"urls"]];
    }
#endif

    id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
    if ([url isKindOfClass:NSString.class] && [url length] > 0) {
        return url;
    }

    id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
    return [self urlStringInURLsValue:urls];
}

- (NSString *)urlStringInURLsValue:(id)value {
    if (![value isKindOfClass:NSArray.class]) {
        return nil;
    }

    NSArray *urls = value;
    if (urls.count == 0 || ![urls[0] isKindOfClass:NSString.class] || [urls[0] length] == 0) {
        return nil;
    }

    NSString *selectedURL = urls[0];
    for (NSUInteger index = 1; index + 1 < urls.count; index += 2) {
        id thresholdValue = urls[index];
        id candidateValue = urls[index + 1];
        if (![thresholdValue respondsToSelector:@selector(doubleValue)] ||
            ![candidateValue isKindOfClass:NSString.class] || [candidateValue length] == 0) {
            continue;
        }
        if ([thresholdValue doubleValue] <= kCFCoreFoundationVersionNumber) {
            selectedURL = candidateValue;
        }
    }
    return selectedURL;
}

- (BOOL)openURL:(NSURL *)url listenerName:(NSString *)listenerName {
#if LA_TESTING
    LATTestingLastOpenedURL = url;
    LATTestingLastOpenedListenerName = [listenerName copy];
    if (LATTestingOpenHandler) {
        return LATTestingOpenHandler(url, listenerName ?: @"");
    }
#endif

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        NSLog(@"libactivator: LSApplicationWorkspace is unavailable");
        return NO;
    }
    LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
    if (![workspace respondsToSelector:@selector(openSensitiveURL:withOptions:error:)]) {
        NSLog(@"libactivator: LSApplicationWorkspace does not support openSensitiveURL:withOptions:error:");
        return NO;
    }

    dispatch_async([self.class URLActionOpenQueue], ^{
        NSError *error = nil;
        BOOL opened = [workspace openSensitiveURL:url withOptions:@{} error:&error];
        if (!opened) {
            NSLog(@"libactivator: Failed to open URL action %@ URL %@: %@", listenerName ?: @"",
                  url.absoluteString ?: @"", error.localizedDescription ?: @"unknown error");
        }
    });

    return YES;
}

+ (dispatch_queue_t)URLActionOpenQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.libactivator.url-actions.open", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

#if LA_TESTING
+ (void)setTestingOpenHandler:(LATURLActionOpenHandler)handler {
    LATTestingOpenHandler = [handler copy];
}

+ (void)setTestingURLMetadata:(NSDictionary *)metadata forListenerName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return;
    }
    if (!LATTestingURLMetadata) {
        LATTestingURLMetadata = [[NSMutableDictionary alloc] init];
    }
    if (metadata) {
        LATTestingURLMetadata[listenerName] = metadata;
    } else {
        [LATTestingURLMetadata removeObjectForKey:listenerName];
    }
}

+ (NSURL *)testingLastOpenedURL {
    return LATTestingLastOpenedURL;
}

+ (NSString *)testingLastOpenedListenerName {
    return LATTestingLastOpenedListenerName;
}

+ (void)resetTestingState {
    LATTestingOpenHandler = nil;
    LATTestingLastOpenedURL = nil;
    LATTestingLastOpenedListenerName = nil;
    [LATTestingURLMetadata removeAllObjects];
}
#endif

@end
