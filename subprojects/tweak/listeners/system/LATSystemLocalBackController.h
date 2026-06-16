//
//  LATSystemLocalBackController.h
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LAActivator;
@class LAEvent;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemLocalBackController : NSObject

- (BOOL)performBackForEvent:(LAEvent *)event activator:(LAActivator *)activator listenerName:(NSString *)listenerName;
- (BOOL)performLocalBackForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
