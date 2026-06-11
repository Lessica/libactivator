//
//  LATHardwareActionCommand.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "hardware/LATHardwareActionCommand.h"

@implementation LATHardwareActionCommand

- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATHardwareActionKindHID;
        _page = page;
        _usage = usage;
    }
    return self;
}

- (instancetype)initWithVibrateListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
        _selectorName = [selectorName copy];
        _kind = LATHardwareActionKindVibrate;
        _page = 0;
        _usage = 0;
    }
    return self;
}

@end
