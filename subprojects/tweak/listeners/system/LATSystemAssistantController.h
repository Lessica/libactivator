//
//  LATSystemAssistantController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemAssistantController : NSObject
- (BOOL)activateVirtualAssistantForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
