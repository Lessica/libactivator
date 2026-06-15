//
//  LATComposeActionCommand.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "compose/LATComposeActionCommand.h"

@implementation LATComposeActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATComposeActionKind)kind {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = kind;
    }
    return self;
}

@end
