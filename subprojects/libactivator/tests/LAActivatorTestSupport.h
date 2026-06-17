//
//  LAActivatorTestSupport.h
//  libactivator
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#if LIBACTIVATOR_TEST_SUPPORT

#import <Foundation/Foundation.h>

@class LAActivator;

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAActivatorTestSupport : NSObject

#pragma mark - Command Handling

+ (NSDictionary<NSString *, id> *)handleCommandWithUserInfo:(NSDictionary<NSString *, id> *)userInfo
                                                  activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END

#endif
