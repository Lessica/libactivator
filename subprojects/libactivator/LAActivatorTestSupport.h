//
//  LAActivatorTestSupport.h
//  libactivator
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#if LA_TESTING

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;

__attribute__((visibility("hidden")))
@interface LAActivatorTestSupport : NSObject
+ (NSDictionary *)handleCommandWithUserInfo:(NSDictionary *)userInfo activator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END

#endif
