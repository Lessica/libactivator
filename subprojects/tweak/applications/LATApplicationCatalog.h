//
//  LATApplicationCatalog.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATApplicationDescriptor;

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationCatalog : NSObject
- (NSArray<LATApplicationDescriptor *> *)visibleApplicationDescriptors;
- (nullable LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier;
- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;
@end

NS_ASSUME_NONNULL_END
