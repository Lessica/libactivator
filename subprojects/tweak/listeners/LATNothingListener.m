//
//  LATNothingListener.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATNothingListener.h"

static NSString *const LATNothingListenerName = @"libactivator.system.nothing";
static NSString *const LATNothingListenerSelector = @"doNothing";

@implementation LATNothingListener

- (instancetype)initWithBuiltInListenerContext:(__unused LATBuiltInListenerContext *)context {
    return [self init];
}

+ (NSArray<NSString *> *)supportedListenerNames {
    return @[ LATNothingListenerName ];
}

+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator {
    if (![listenerName isEqualToString:LATNothingListenerName]) {
        return NO;
    }
    id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
    return [selector isKindOfClass:NSString.class] && [selector isEqualToString:LATNothingListenerSelector];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    event.handled = YES;
}

@end
