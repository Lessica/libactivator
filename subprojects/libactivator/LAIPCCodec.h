//
//  LAIPCCodec.h
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAEvent;

__attribute__((visibility("hidden")))
@interface LAIPCCodec : NSObject

#pragma mark - Reply Builders

+ (NSDictionary *)replyWithOK:(BOOL)ok value:(nullable id)value;
+ (NSDictionary *)eventReplyWithEvent:(LAEvent *)event;
+ (NSDictionary *)smallIconDataReplyWithData:(nullable NSData *)data scale:(CGFloat)scale;

#pragma mark - UserInfo Parsing

+ (nullable NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (NSArray<NSString *> *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (NSArray<NSString *> *)uniqueOrderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (nullable LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo;

#pragma mark - Serialization

+ (NSDictionary *)userInfoWithEvent:(LAEvent *)event;
+ (NSArray<NSDictionary<NSString *, id> *> *)eventDictionariesWithEvents:(NSArray<LAEvent *> *)events;
+ (NSArray<LAEvent *> *)eventsWithDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)eventDictionaries;
+ (nullable id)propertyListValue:(nullable id)value;

@end

NS_ASSUME_NONNULL_END
