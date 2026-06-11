//
//  LADefaultEventDataSource.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LADefaultEventDataSource : NSObject<LAEventDataSource>

#pragma mark - Registration

- (void)registerAvailableEventsWithActivator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
