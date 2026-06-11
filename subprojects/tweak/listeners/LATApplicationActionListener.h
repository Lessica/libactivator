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

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationActionListener : NSObject <LAListener>
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher;
- (void)setApplicationDescriptors:(NSDictionary<NSString *, LATApplicationDescriptor *> *)descriptorsByIdentifier;
- (nullable LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
