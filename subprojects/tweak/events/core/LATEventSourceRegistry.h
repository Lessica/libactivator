//
//  LATEventSourceRegistry.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSource.h"

@class LAActivator;

NS_ASSUME_NONNULL_BEGIN

// All registry access is main-queue confined.
@interface LATEventSourceRegistry : NSObject

@property(nonatomic, copy, readonly) NSArray<id<LATEventSource>> *eventSources;
@property(nonatomic, assign, readonly, getter=isStarted) BOOL started;
@property(nonatomic, assign, readonly, getter=isInvalidated) BOOL invalidated;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (BOOL)registerEventSource:(id<LATEventSource>)eventSource;
- (BOOL)unregisterEventSource:(id<LATEventSource>)eventSource;
- (BOOL)reloadEventNamesForEventSource:(id<LATEventSource>)eventSource;

- (NSArray<id<LATEventSource>> *)eventSourcesForEventName:(NSString *)eventName;
- (NSSet<NSString *> *)interestedEventNamesForEventSource:(id<LATEventSource>)eventSource;
- (BOOL)isInterestedInEventSource:(id<LATEventSource>)eventSource;

- (void)start;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
