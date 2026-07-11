//
//  LATNetworkEventDataSource.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATEventDefinitionProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATNetworkEventDataSource : NSObject <LAEventDataSource, LATEventDefinitionProvider>

@property(nonatomic, copy, readonly) NSSet<NSString *> *configuredEventNames;
@property(nonatomic, weak, nullable) LATEventDefinitionRegistry *eventDefinitionRegistry;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
