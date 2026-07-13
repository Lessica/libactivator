//
//  LATestEventSourceFixture.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATestEventSourceFixture : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

- (LATEventSourceContext *)contextWithPreviousEventSources:(NSArray<id<LATEventSource>> *)previousEventSources;
- (nullable __kindof NSObject<LATEventSource> *)interestedEventSourceOfClass:(Class<LATEventSource>)eventSourceClass
                                                        previousEventSources:
                                                            (NSArray<id<LATEventSource>> *)previousEventSources;
- (NSUInteger)dispatchCountForEventName:(NSString *)eventName;

@end

NS_ASSUME_NONNULL_END
