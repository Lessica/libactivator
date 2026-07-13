//
//  LATEventSourceDefinitionBinding.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDefinitionProvider.h"
#import "LATEventSource.h"

@class LATEventSourceRegistry;

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventSourceDefinitionConsumer <LATEventSource>
@property(nonatomic, copy, readonly) NSSet<NSString *> *configuredEventNames;
- (void)updateConfiguredEventNames:(NSSet<NSString *> *)configuredEventNames;
@end

@interface LATEventSourceDefinitionBinding : NSObject

@property(nonatomic, strong, readonly) id<LATEventDefinitionProvider> provider;
@property(nonatomic, strong, readonly) id<LATEventSourceDefinitionConsumer> eventSource;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProvider:(id<LATEventDefinitionProvider>)provider
                     eventSource:(id<LATEventSourceDefinitionConsumer>)eventSource NS_DESIGNATED_INITIALIZER;

- (BOOL)applyEventNames:(NSSet<NSString *> *)eventNames
     previousEventNames:(NSSet<NSString *> *)previousEventNames
    eventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry;

@end

NS_ASSUME_NONNULL_END
