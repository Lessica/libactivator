//
//  LATestEventDataSource.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventDataSource.h"

@implementation LATestEventDataSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _requiresAssignment = YES;
        _compatibleModes = @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
    }
    return self;
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    return [NSString stringWithFormat:@"Title %@", eventName ?: @""];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    return @"Testing";
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    return [NSString stringWithFormat:@"Description %@", eventName ?: @""];
}

- (BOOL)eventWithNameIsHidden:(NSString *)eventName {
    return self.hidden;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName {
    return self.requiresAssignment;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    return eventMode.length == 0 || [self.compatibleModes containsObject:eventMode];
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
    return self.supportsUnlockingDeviceToSend;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    return self.supportsRemoval;
}

- (void)removeEventWithName:(NSString *)eventName {
    self.removalCount += 1;
}

@end
