//
//  LATestTestingProtocols.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATestBuiltInActionListenerTesting <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
+ (void)setTestingSelector:(NSString *)selector forListenerName:(NSString *)listenerName;
+ (void)resetTestingState;
@end

@protocol LATestURLActionListenerTesting <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
+ (void)setTestingOpenHandler:(BOOL (^)(NSURL *url, NSString *listenerName))handler;
+ (void)setTestingURLMetadata:(NSDictionary *)metadata forListenerName:(NSString *)listenerName;
+ (nullable NSURL *)testingLastOpenedURL;
+ (nullable NSString *)testingLastOpenedListenerName;
+ (void)resetTestingState;
@end

@protocol LATestMediaActionListenerTesting <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
+ (void)setTestingSendHandler:(BOOL (^)(NSString *listenerName, uint32_t page, uint32_t usage))handler;
+ (void)setTestingSelector:(NSString *)selector forListenerName:(NSString *)listenerName;
+ (void)setTestingNowPlayingApplicationIdentifier:(nullable NSString *)identifier;
+ (nullable NSString *)testingLastSentListenerName;
+ (uint32_t)testingLastSentPage;
+ (uint32_t)testingLastSentUsage;
+ (NSArray<NSString *> *)testingSentPhases;
+ (void)resetTestingState;
@end

@protocol LATestRingerActionListenerTesting <LATestBuiltInActionListenerTesting>
+ (void)setTestingActionHandler:(BOOL (^)(NSString *listenerName, NSString *phase))handler;
+ (nullable NSString *)testingLastActionListenerName;
+ (nullable NSString *)testingLastActionPhase;
@end

NS_ASSUME_NONNULL_END
