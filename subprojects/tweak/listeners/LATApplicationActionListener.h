//
//  LATApplicationActionListener.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATSpringBoardInstanceProviding.h"

@class LATApplicationDescriptor;
@class LATApplicationLauncher;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationActionListener : NSObject <LAListener>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
              runtimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource
     springBoardInstanceProvider:(nullable id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
    NS_DESIGNATED_INITIALIZER;

- (void)setApplicationDescriptors:(NSDictionary<NSString *, LATApplicationDescriptor *> *)descriptorsByIdentifier;
- (nullable LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier;
- (BOOL)shouldHandleApplicationDescriptor:(nullable LATApplicationDescriptor *)descriptor
                                 forEvent:(LAEvent *)event
                                activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
