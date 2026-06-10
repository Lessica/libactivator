//
//  LATMediaActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATMediaActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>
+ (void)noteVolumeControlInstance:(id)volumeControl;
+ (void)noteRingerControlInstance:(id)ringerControl;
@end

#if LA_TESTING
typedef BOOL (^LATMediaActionSendHandler)(NSString *listenerName, uint32_t page, uint32_t usage);

@interface LATMediaActionListener (Testing)
+ (void)setTestingSendHandler:(nullable LATMediaActionSendHandler)handler;
+ (void)setTestingSelector:(nullable NSString *)selector forListenerName:(NSString *)listenerName;
+ (nullable NSString *)testingLastSentListenerName;
+ (uint32_t)testingLastSentPage;
+ (uint32_t)testingLastSentUsage;
+ (NSArray<NSString *> *)testingSentPhases;
+ (void)resetTestingState;
@end
#endif

NS_ASSUME_NONNULL_END
