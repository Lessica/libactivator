//
//  LATEventDefinitionRegistry.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDefinitionProvider.h"

@class LAActivator;
@class LATEventDefinitionRegistry;

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventDefinitionRegistryDelegate <NSObject>

- (BOOL)eventDefinitionRegistry:(LATEventDefinitionRegistry *)registry
                applyEventNames:(NSSet<NSString *> *)eventNames
             previousEventNames:(NSSet<NSString *> *)previousEventNames
                    forProvider:(id<LATEventDefinitionProvider>)provider;

@end

// All registry access is main-queue confined.
@interface LATEventDefinitionRegistry : NSObject

// Configure before registering providers. The composition delegate remains
// stable while any provider is registered.
@property(nonatomic, weak, nullable) id<LATEventDefinitionRegistryDelegate> delegate;
@property(nonatomic, copy, readonly) NSArray<id<LATEventDefinitionProvider>> *providers;
@property(nonatomic, assign, readonly) NSUInteger generation;
@property(nonatomic, assign, readonly, getter=isInvalidated) BOOL invalidated;

+ (NSNotificationName)changedNotification;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (BOOL)registerProvider:(id<LATEventDefinitionProvider>)provider;
- (BOOL)unregisterProvider:(id<LATEventDefinitionProvider>)provider;
- (BOOL)reloadEventNamesForProvider:(id<LATEventDefinitionProvider>)provider;

- (nullable id<LATEventDefinitionProvider>)providerWithIdentifier:(NSString *)identifier;
- (nullable id<LATEventDefinitionProvider>)providerForEventName:(NSString *)eventName;
- (NSSet<NSString *> *)activeEventNamesForProvider:(id<LATEventDefinitionProvider>)provider;

// The returned property list contains Generation and ordered Providers. Each
// provider entry contains Identifier, EventNames, and Templates.
- (NSDictionary<NSString *, id> *)eventCreationCatalog;
- (nullable NSString *)createEventWithProviderIdentifier:(NSString *)providerIdentifier
                                      templateIdentifier:(NSString *)templateIdentifier
                                           configuration:(id)configuration
                                      expectedGeneration:(NSUInteger)expectedGeneration;
- (nullable id)configurationForEventName:(NSString *)eventName expectedGeneration:(NSUInteger)expectedGeneration;
- (BOOL)saveConfiguration:(id)configuration
             forEventName:(NSString *)eventName
       expectedGeneration:(NSUInteger)expectedGeneration;
- (BOOL)removeEventWithName:(NSString *)eventName expectedGeneration:(NSUInteger)expectedGeneration;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
