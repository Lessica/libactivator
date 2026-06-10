//
//  LATBuiltInListenerRegistry.h
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATBuiltInListenerRegistry : NSObject
+ (void)registerWithActivator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
