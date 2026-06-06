//
//  UIImageView+Activator.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/UIImageView+Activator.h>

#import <objc/runtime.h>

static char LAActivatorListenerImageIsThreadedKey;
static char LAActivatorListenerNameKey;

@implementation UIImageView (Activator)

- (void)setActivatorListenerImageIsThreaded:(BOOL)activatorListenerImageIsThreaded {
    objc_setAssociatedObject(self, &LAActivatorListenerImageIsThreadedKey, @(activatorListenerImageIsThreaded),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)activatorListenerImageIsThreaded {
    return [objc_getAssociatedObject(self, &LAActivatorListenerImageIsThreadedKey) boolValue];
}

- (void)setActivatorListenerName:(NSString *)activatorListenerName {
    objc_setAssociatedObject(self, &LAActivatorListenerNameKey, activatorListenerName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)activatorListenerName {
    return objc_getAssociatedObject(self, &LAActivatorListenerNameKey);
}

@end
