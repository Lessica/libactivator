//
//  LAScreenWakeCoordinator.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;

__attribute__((visibility("hidden")))
@interface LAScreenWakeCoordinator : NSObject
- (void)startObservingScreenStateWithActivator:(LAActivator *)activator;
- (BOOL)wakeScreenForReason:(NSString *)reason completion:(dispatch_block_t)completion;
@end

NS_ASSUME_NONNULL_END
