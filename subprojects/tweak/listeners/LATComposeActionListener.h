//
//  LATComposeActionListener.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATBuiltInListenerRegistrant.h"

#import <Activator/Activator.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATComposeActionListener : NSObject <LATBuiltInListenerRegistrant>
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
- (BOOL)shouldHandleListenerName:(NSString *)listenerName activator:(nullable LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
