//
//  LATSystemActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
@end

NS_ASSUME_NONNULL_END
