//
//  LATTelephonyCallStateObserver.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATTelephonyCallStateObserver : NSObject

@property(nonatomic, assign, readonly) int lastKnownCallCount;

- (void)telephonyCallStateDidChangeWithName:(CFStringRef)name;

@end

NS_ASSUME_NONNULL_END
