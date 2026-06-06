//
//  LAApplicationIconProvider.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAApplicationIconProvider.h"

#import <dispatch/dispatch.h>

@interface UIImage (LAApplicationIconProvider)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

@implementation LAApplicationIconProvider

+ (instancetype)sharedProvider {
    static dispatch_once_t onceToken;
    static LAApplicationIconProvider *provider;
    dispatch_once(&onceToken, ^{
        provider = [[self alloc] init];
    });
    return provider;
}

- (UIImage *)smallIconForDisplayIdentifier:(NSString *)displayIdentifier scale:(CGFloat)scale {
    if (displayIdentifier.length == 0 ||
        ![UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
        return nil;
    }
    return [UIImage _applicationIconImageForBundleIdentifier:displayIdentifier format:0 scale:scale];
}

@end
