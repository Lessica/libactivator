//
//  LATNetworkEventSource.h
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATEventSource.h"
#import "LATEventSourceDefinitionBinding.h"
#import "LATEventSourceDependencies.h"
#import "LATEventSourceIngress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATNetworkEventSource
    : NSObject <LATEventSource, LATEventSourceNetworkStateIngress, LATEventSourceDefinitionConsumer>

@property(nonatomic, copy, readonly) NSSet<NSString *> *configuredEventNames;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                     definitionQuerying:(id<LATEventDefinitionQuerying>)definitionQuerying NS_DESIGNATED_INITIALIZER;

// Main-queue confined for start and state reads. Hook and network monitor entry
// points may call noteNetworkStateMayHaveChangedWithReason: from any queue.
- (void)start;
- (void)noteNetworkStateMayHaveChangedWithReason:(NSString *)reason;
- (void)updateConfiguredEventNames:(NSSet<NSString *> *)configuredEventNames;

@end

NS_ASSUME_NONNULL_END
