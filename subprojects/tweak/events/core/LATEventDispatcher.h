//
//  LATEventDispatcher.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceDependencies.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATEventDispatcher
    : NSObject <LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying, LATEventDefinitionQuerying>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
