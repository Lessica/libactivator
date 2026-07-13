//
//  LATestEventSource.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATestEventSource : NSObject <LATEventSource>

@property(nonatomic, copy) NSString *eventSourceIdentifier;
@property(nonatomic, copy) NSSet<NSString *> *eventNames;
@property(nonatomic, assign) LATEventSourceInterestPolicy interestPolicy;
@property(nonatomic, assign) NSUInteger startCount;
@property(nonatomic, assign) NSUInteger invalidateCount;
@property(nonatomic, assign) NSUInteger interestChangeCount;
@property(nonatomic, assign) NSUInteger interestedEventNamesChangeCount;
@property(nonatomic, assign, getter=isInterested) BOOL interested;
@property(nonatomic, copy) NSSet<NSString *> *interestedEventNames;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(NSString *)identifier
                        eventNames:(NSSet<NSString *> *)eventNames
                    interestPolicy:(LATEventSourceInterestPolicy)interestPolicy NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
