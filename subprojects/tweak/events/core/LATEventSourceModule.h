//
//  LATEventSourceModule.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDispatcher.h"
#import "LATEventSourceDefinitionBinding.h"

NS_ASSUME_NONNULL_BEGIN

NS_INLINE NSString *LATEventSourceServiceKey(Protocol *protocol) { return NSStringFromProtocol(protocol); }

@class LATEventSourceModuleContext;
@class LATEventSourceModuleResult;

@protocol LATEventSourceModule <NSObject>

@required
+ (NSString *)eventSourceModuleIdentifier;
+ (NSInteger)eventSourceModulePriority;
+ (nullable LATEventSourceModuleResult *)loadWithContext:(LATEventSourceModuleContext *)context
                                                   error:(NSError *_Nullable *_Nullable)error;

@optional
+ (NSArray<NSString *> *)requiredEventSourceModuleIdentifiers;
+ (NSArray<NSString *> *)eventSourceModuleOrderingDependencies;
+ (BOOL)isSupportedWithContext:(LATEventSourceModuleContext *)context;

@end

@interface LATEventSourceModuleContext : NSObject

@property(nonatomic, strong, readonly) LAActivator *activator;
@property(nonatomic, strong, readonly)
    id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying, LATEventDefinitionQuerying>
        eventDispatcher;
@property(nonatomic, strong, readonly) id<LATRuntimeLockStateUpdating> runtimeLockStateUpdater;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator
                  eventDispatcher:(id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying,
                                      LATEventDefinitionQuerying>)eventDispatcher
          runtimeLockStateUpdater:(id<LATRuntimeLockStateUpdating>)runtimeLockStateUpdater NS_DESIGNATED_INITIALIZER;

- (nullable id)serviceForProtocol:(Protocol *)protocol;

@end

@interface LATEventSourceModuleResult : NSObject

@property(nonatomic, copy, readonly) NSArray<id<LATEventSource>> *eventSources;
@property(nonatomic, copy, readonly) NSArray<id<LATEventDefinitionProvider>> *definitionProviders;
@property(nonatomic, copy, readonly) NSArray<LATEventSourceDefinitionBinding *> *definitionBindings;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *exportedServices;

- (instancetype)initWithEventSources:(NSArray<id<LATEventSource>> *)eventSources
                 definitionProviders:(NSArray<id<LATEventDefinitionProvider>> *)definitionProviders
                  definitionBindings:(NSArray<LATEventSourceDefinitionBinding *> *)definitionBindings
                    exportedServices:(NSDictionary<NSString *, id> *)exportedServices NS_DESIGNATED_INITIALIZER;

@end

@interface LATEventSourceModuleContext (Loader)
- (BOOL)registerService:(id)service forProtocolName:(NSString *)protocolName;
- (void)removeServiceForProtocolName:(NSString *)protocolName;
@end

NS_ASSUME_NONNULL_END
