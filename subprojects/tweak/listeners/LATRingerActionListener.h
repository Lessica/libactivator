//
//  LATRingerActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATRingerActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
+ (void)noteRingerControlInstance:(id)ringerControl;
@end

#if LA_TESTING
typedef BOOL (^LATRingerActionHandler)(NSString *listenerName, NSString *phase);

@interface LATRingerActionListener (Testing)
+ (void)setTestingActionHandler:(nullable LATRingerActionHandler)handler;
+ (void)setTestingSelector:(nullable NSString *)selector forListenerName:(NSString *)listenerName;
+ (nullable NSString *)testingLastActionListenerName;
+ (nullable NSString *)testingLastActionPhase;
+ (void)resetTestingState;
@end
#endif

NS_ASSUME_NONNULL_END
