//
//  LATSystemSwitcherController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemMainQueueActionPerformer.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemSwitcherController : LATSystemMainQueueActionPerformer
- (BOOL)activateSwitcherForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
