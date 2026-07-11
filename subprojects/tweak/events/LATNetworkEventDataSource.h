//
//  LATNetworkEventDataSource.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@class LATEventSourceRegistry;
@class LATNetworkEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATNetworkEventDataSource : NSObject <LAEventDataSource>

@property(nonatomic, copy, readonly) NSSet<NSString *> *configuredEventNames;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator
                      eventSource:(LATNetworkEventSource *)eventSource NS_DESIGNATED_INITIALIZER;

- (void)attachEventSourceRegistry:(LATEventSourceRegistry *)eventSourceRegistry;
- (nullable NSString *)addEventWithBaseName:(NSString *)baseEventName networkName:(NSString *)networkName;

@end

NS_ASSUME_NONNULL_END
