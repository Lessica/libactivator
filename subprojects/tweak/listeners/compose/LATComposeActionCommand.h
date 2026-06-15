//
//  LATComposeActionCommand.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LATComposeActionKind) {
    LATComposeActionKindMail,
    LATComposeActionKindText,
    LATComposeActionKindNote,
};

@interface LATComposeActionCommand : NSObject

@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATComposeActionKind kind;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATComposeActionKind)kind NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
