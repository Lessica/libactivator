//
//  LATBuiltInListenerRegistrant.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATSpringBoardInstanceProviding.h"

#import <Activator/Activator.h>

@class LATApplicationLauncher;
@class LATRuntimeStateSource;
@protocol LATEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInListenerContext : NSObject

@property(nonatomic, strong, readonly) LATApplicationLauncher *applicationLauncher;
@property(nonatomic, strong, readonly) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, weak, nullable, readonly) id<LATSpringBoardInstanceProviding> springBoardInstanceProvider;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource
                springBoardInstanceProvider:(nullable id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
                               eventSources:(NSArray<id<LATEventSource>> *)eventSources NS_DESIGNATED_INITIALIZER;

- (nullable id)eventSourceConformingToProtocol:(Protocol *)protocol;

@end

@protocol LATBuiltInListenerRegistrant <LAListener>

- (nullable instancetype)initWithBuiltInListenerContext:(LATBuiltInListenerContext *)context;

+ (NSArray<NSString *> *)supportedListenerNames;
+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
