//
//  LATApplicationActionListener.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class LATApplicationDescriptor;
@class LATApplicationLauncher;
@class LATBuiltInRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationActionListener : NSObject <LAListener>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
                        registry:(nullable LATBuiltInRegistry *)registry NS_DESIGNATED_INITIALIZER;

- (void)setApplicationDescriptors:(NSDictionary<NSString *, LATApplicationDescriptor *> *)descriptorsByIdentifier;
- (nullable LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier;
- (BOOL)shouldHandleApplicationDescriptor:(nullable LATApplicationDescriptor *)descriptor
                                 forEvent:(LAEvent *)event
                                activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
