//
//  LATHardwareActionCommand.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LATHardwareActionKind) {
    LATHardwareActionKindHID,
    LATHardwareActionKindVibrate,
};

@interface LATHardwareActionCommand : NSObject

@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATHardwareActionKind kind;
@property(nonatomic, assign, readonly) uint32_t page;
@property(nonatomic, assign, readonly) uint32_t usage;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                page:(uint32_t)page
                               usage:(uint32_t)usage;
- (instancetype)initWithVibrateListenerName:(NSString *)listenerName selectorName:(NSString *)selectorName;

@end

NS_ASSUME_NONNULL_END
