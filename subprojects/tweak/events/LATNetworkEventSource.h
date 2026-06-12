//
//  LATNetworkEventSource.h
//  ActivatorTweak
//
//  Created by Lessica on 6/12/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATNetworkEventSource : NSObject

// Main-queue confined for start and state reads. Hook and network monitor entry
// points may call noteNetworkStateMayHaveChangedWithReason: from any queue.
- (void)start;
- (void)noteNetworkStateMayHaveChangedWithReason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
