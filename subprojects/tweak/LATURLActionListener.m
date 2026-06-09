//
//  LATURLActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATURLActionListener.h"

#import <UIKit/UIKit.h>

@interface UIApplication (LATSpringBoardURLAction)
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)publicURLsOnly;
@end

@interface LATURLActionListener ()
- (nullable NSString *)urlStringForListenerName:(NSString *)listenerName activator:(LAActivator *)activator;
- (nullable NSString *)urlStringInURLsValue:(id)value;
- (BOOL)openURL:(NSURL *)url listenerName:(NSString *)listenerName;
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
    __block BOOL opened = NO;
    dispatch_block_t openBlock = ^{
#if LA_TESTING
        LATTestingLastOpenedURL = url;
        LATTestingLastOpenedListenerName = [listenerName copy];
        if (LATTestingOpenHandler) {
            opened = LATTestingOpenHandler(url, listenerName ?: @"");
            return;
        }
#endif

        UIApplication *application = UIApplication.sharedApplication;
        if (![application respondsToSelector:@selector(applicationOpenURL:publicURLsOnly:)]) {
            NSLog(@"libactivator: SpringBoard does not support applicationOpenURL:publicURLsOnly:");
            return;
        }
        [application applicationOpenURL:url publicURLsOnly:NO];
        opened = YES;
    };

    if ([NSThread isMainThread]) {
        openBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), openBlock);
    }
    return opened;
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
