//
//  LATestTestingProtocols.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATestBuiltInListenerAllowlist <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
@end

@protocol LATestSelectorBackedBuiltInListener <LATestBuiltInListenerAllowlist>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
