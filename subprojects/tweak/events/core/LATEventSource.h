//
//  LATEventSource.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceDependencies.h"

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LATEventSourceInterestPolicy) {
    LATEventSourceInterestPolicyAlways,
    LATEventSourceInterestPolicyAssignedInCurrentMode,
};

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventDefinitionProvider;
@protocol LATEventSource;

@interface LATEventSourceContext : NSObject

@property(nonatomic, strong, readonly) LAActivator *activator;
@property(nonatomic, strong, readonly)
    id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying, LATEventDefinitionQuerying>
        eventDispatcher;
@property(nonatomic, strong, readonly) id<LATRuntimeLockStateUpdating> runtimeLockStateUpdater;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator
                  eventDispatcher:(id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying,
                                      LATEventDefinitionQuerying>)eventDispatcher
          runtimeLockStateUpdater:(id<LATRuntimeLockStateUpdating>)runtimeLockStateUpdater
             previousEventSources:(NSArray<id<LATEventSource>> *)previousEventSources NS_DESIGNATED_INITIALIZER;

- (nullable id)eventSourceConformingToProtocol:(Protocol *)protocol;

@end

@protocol LATEventSource <NSObject>

@required

- (nullable instancetype)initWithEventSourceContext:(LATEventSourceContext *)context;

@property(nonatomic, copy, readonly) NSString *eventSourceIdentifier;
@property(nonatomic, copy, readonly) NSSet<NSString *> *eventNames;
@property(nonatomic, assign, readonly) LATEventSourceInterestPolicy interestPolicy;

- (void)start;
- (void)invalidate;

@optional

- (id<LATEventDefinitionProvider>)eventDefinitionProviderForContext:(LATEventSourceContext *)context;
@property(nonatomic, copy, readonly) NSSet<NSString *> *interestEventNames;
- (void)eventSourceInterestDidChange:(BOOL)interested;
- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames;

@end

NS_ASSUME_NONNULL_END
