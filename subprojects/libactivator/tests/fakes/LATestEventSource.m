//
//  LATestEventSource.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSource.h"

@implementation LATestEventSource

- (instancetype)initWithEventSourceContext:(__unused LATEventSourceContext *)context {
    return [self initWithIdentifier:@"testing.context-source"
                         eventNames:[NSSet set]
                     interestPolicy:LATEventSourceInterestPolicyAlways];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                        eventNames:(NSSet<NSString *> *)eventNames
                    interestPolicy:(LATEventSourceInterestPolicy)interestPolicy {
    self = [super init];
    if (self) {
        _eventSourceIdentifier = [identifier copy];
        _eventNames = [eventNames copy];
        _interestPolicy = interestPolicy;
        _interestedEventNames = [NSSet set];
    }
    return self;
}

- (void)start {
    self.startCount += 1;
}

- (void)invalidate {
    self.invalidateCount += 1;
}

- (void)eventSourceInterestDidChange:(BOOL)interested {
    self.interestChangeCount += 1;
    self.interested = interested;
}

- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames {
    self.interestedEventNamesChangeCount += 1;
    self.interestedEventNames = interestedEventNames;
}

@end
