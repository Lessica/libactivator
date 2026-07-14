//
//  LATBuiltInRegistry.h
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATSpringBoardInstanceProviding.h"

@class SBRingerControl;
@class SBVolumeControl;
@class CSCoverSheetViewController;
@class LATEventDefinitionRegistry;
@class LATEventSourceRegistry;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInRegistry : NSObject <LATSpringBoardInstanceProviding>

#pragma mark - Built-In Classes

+ (NSArray<Class> *)builtInEventSourceClasses;
+ (NSArray<Class> *)builtInListenerClasses;

#pragma mark - Lifecycle

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

#pragma mark - SpringBoard Instances

@property(nonatomic, weak, nullable) CSCoverSheetViewController *coverSheetViewControllerInstance;
@property(nonatomic, weak, nullable) SBRingerControl *ringerControlInstance;
@property(nonatomic, weak, nullable) SBVolumeControl *volumeControlInstance;

#pragma mark - Event Sources

@property(nonatomic, strong, readonly) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readonly) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readonly) LATEventSourceRegistry *eventSourceRegistry;

- (void)startEventSources;
- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol;

#pragma mark - Application Catalog

- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason;

#pragma mark - Device Capabilities

- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled;

@end

NS_ASSUME_NONNULL_END
