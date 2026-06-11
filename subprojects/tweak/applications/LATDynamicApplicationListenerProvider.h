//
//  LATDynamicApplicationListenerProvider.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class LATApplicationActionListener;
@class LATApplicationCatalog;
@class LATApplicationDescriptor;

NS_ASSUME_NONNULL_BEGIN

@interface LATDynamicApplicationListenerProvider : NSObject
- (instancetype)initWithActivator:(LAActivator *)activator
                          catalog:(LATApplicationCatalog *)catalog
                         listener:(LATApplicationActionListener *)listener;
- (void)start;
- (void)refreshApplications;
+ (NSArray<LATApplicationDescriptor *> *)visibleApplicationDescriptors;
@end

NS_ASSUME_NONNULL_END
