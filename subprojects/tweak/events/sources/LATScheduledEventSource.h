//
//  LATScheduledEventSource.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"
#import "LATUIKitSolarTransitionMonitor.h"

NS_ASSUME_NONNULL_BEGIN

typedef id<LATSolarTransitionMonitoring> _Nullable (^LATSolarTransitionMonitorFactory)(void);

@interface LATScheduledEventSource : NSObject <LATEventSource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider
                         monitorFactory:(LATSolarTransitionMonitorFactory)monitorFactory NS_DESIGNATED_INITIALIZER;

#if DEBUG
- (BOOL)la_testingHasActiveMonitor;
#endif

@end

NS_ASSUME_NONNULL_END
