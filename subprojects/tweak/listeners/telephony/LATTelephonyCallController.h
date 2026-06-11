//
//  LATTelephonyCallController.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATTelephonyCallStateObserver;

NS_ASSUME_NONNULL_BEGIN

@interface LATTelephonyCallController : NSObject
@property(nonatomic, strong, readonly) LATTelephonyCallStateObserver *callStateObserver;
- (BOOL)answerIncomingCallForListenerName:(NSString *)listenerName;
- (BOOL)disconnectCallsForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
