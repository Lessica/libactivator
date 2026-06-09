//
//  LALegacyPreferenceBridge.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivatorBackend;

__attribute__((visibility("hidden")))
@interface LALegacyPreferenceBridge : NSObject
- (instancetype)initWithBackend:(LAActivatorBackend *)backend;
- (nullable id)objectForPreferenceKey:(NSString *)key;
- (BOOL)setObject:(nullable id)object forPreferenceKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
