//
//  LATBuiltInRegistry.h
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class SBRingerControl;
@class SBVolumeControl;
@class CSCoverSheetViewController;
@class LATEventDefinitionRegistry;
@class LATEventSourceRegistry;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInRegistry : NSObject

// Captured SpringBoard-owned instances
@property(nonatomic, weak, nullable) CSCoverSheetViewController *coverSheetViewControllerInstance;
@property(nonatomic, weak, nullable) SBRingerControl *ringerControlInstance;
@property(nonatomic, weak, nullable) SBVolumeControl *volumeControlInstance;

// Event sources
@property(nonatomic, strong, readonly) LATRuntimeStateSource *runtimeStateSource;
@property(nonatomic, strong, readonly) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, strong, readonly) LATEventSourceRegistry *eventSourceRegistry;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (void)startEventSources;
- (NSArray<id> *)eventSourcesConformingToProtocol:(Protocol *)protocol;
- (nullable id)eventSourceServiceForProtocol:(Protocol *)protocol;
- (void)noteApplicationCatalogMayHaveChangedWithReason:(NSString *)reason;
- (BOOL)legacyHomeButtonTouchStreamHookShouldBeInstalled;

@end

NS_ASSUME_NONNULL_END
