//
//  LARemoteListener.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LARemoteListener : NSObject<LAListener>

#pragma mark - Lifecycle

+ (instancetype)sharedListener;

@end

NS_ASSUME_NONNULL_END
