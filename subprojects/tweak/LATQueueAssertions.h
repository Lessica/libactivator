//
//  LATQueueAssertions.h
//  libactivator
//
//  Created by OpenAI on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <dispatch/dispatch.h>

#define LATAssertMainQueue() dispatch_assert_queue_debug(dispatch_get_main_queue())
