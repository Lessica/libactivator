//
//  LATestEventDefinitionRegistrySuite.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRecorder.h"

@class LAActivator;

NS_ASSUME_NONNULL_BEGIN

@interface LATestEventDefinitionRegistrySuite : NSObject

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
