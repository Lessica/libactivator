//
//  LAActivatorIPCCodec.h
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAEvent;

@interface LAActivatorIPCCodec : NSObject
+ (NSDictionary *)replyWithOK:(BOOL)ok value:(nullable id)value;
+ (NSDictionary *)eventReplyWithEvent:(LAEvent *)event;
+ (nullable NSString *)stringInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (NSArray *)stringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (NSArray *)uniqueOrderedStringArrayInUserInfo:(NSDictionary *)userInfo forKey:(NSString *)key;
+ (nullable LAEvent *)eventWithUserInfo:(NSDictionary *)userInfo;
+ (NSDictionary *)userInfoWithEvent:(LAEvent *)event;
+ (NSArray *)eventDictionariesWithEvents:(NSArray *)events;
+ (NSArray *)eventsWithDictionaries:(NSArray *)eventDictionaries;
+ (nullable id)propertyListValue:(nullable id)value;
+ (NSDictionary *)smallIconDataReplyWithData:(nullable NSData *)data scale:(CGFloat)scale;
@end

NS_ASSUME_NONNULL_END
