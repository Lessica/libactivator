//
//  LAQueueAssertions.h
//  libactivator
//
//  Created by Lessica on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <dispatch/dispatch.h>

#define LAAssertMainQueue() dispatch_assert_queue_debug(dispatch_get_main_queue())
