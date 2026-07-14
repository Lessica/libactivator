//
//  LATTelephonyActionCommand.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LATTelephonyActionKind) {
    LATTelephonyActionKindAnswerCall,
    LATTelephonyActionKindDisconnectCall,
};

NS_ASSUME_NONNULL_BEGIN

@interface LATTelephonyActionCommand : NSObject

@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATTelephonyActionKind kind;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATTelephonyActionKind)kind NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
