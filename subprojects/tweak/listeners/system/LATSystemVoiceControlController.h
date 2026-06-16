//
//  LATSystemVoiceControlController.h
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemVoiceControlController : NSObject

- (BOOL)toggleVoiceControlForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
