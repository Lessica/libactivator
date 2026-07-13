//
//  LATEventSource.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LATEventSourceInterestPolicy) {
    LATEventSourceInterestPolicyAlways,
    LATEventSourceInterestPolicyAssignedInCurrentMode,
};

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventSource <NSObject>

@required

@property(nonatomic, copy, readonly) NSString *eventSourceIdentifier;
@property(nonatomic, copy, readonly) NSSet<NSString *> *eventNames;
@property(nonatomic, assign, readonly) LATEventSourceInterestPolicy interestPolicy;

- (void)start;
- (void)invalidate;

@optional

@property(nonatomic, copy, readonly) NSSet<NSString *> *interestEventNames;
- (void)eventSourceInterestDidChange:(BOOL)interested;
- (void)eventSourceInterestedEventNamesDidChange:(NSSet<NSString *> *)interestedEventNames;

@end

NS_ASSUME_NONNULL_END
