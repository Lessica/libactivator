//
//  LATEventDispatcher.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDispatcher.h"

@interface LATEventDispatcher ()
@property(nonatomic, strong) LAActivator *activator;
@end

@implementation LATEventDispatcher

- (instancetype)initWithActivator:(LAActivator *)activator {
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
    }
    return self;
}

- (void)dispatchEvent:(LAEvent *)event {
    [self.activator sendEventToListener:event];
}

- (void)abortEvent:(LAEvent *)event {
    [self.activator sendAbortToListener:event];
}

- (void)deactivateEvent:(LAEvent *)event {
    [self.activator sendDeactivateEventToListeners:event];
}

- (NSString *)currentEventMode {
    return self.activator.currentEventMode;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    return self.activator.currentEventModeUnderneathLockScreen;
}

- (BOOL)hasAssignedListenerForEvent:(LAEvent *)event {
    return [self.activator listenerForEvent:event] != nil;
}

- (BOOL)hasEventDefinitionWithName:(NSString *)eventName {
    return [self.activator hasEventWithName:eventName];
}

@end
