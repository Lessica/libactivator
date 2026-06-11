//
//  LATestBuiltInEventSourcesSuite.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRecorder.h"

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestBuiltInEventSourcesSuite : NSObject
+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
