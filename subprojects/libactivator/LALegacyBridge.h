//
//  LALegacyBridge.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LAServerBackend;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LALegacyPreferenceMutation) {
    LALegacyPreferenceMutationNone,
    LALegacyPreferenceMutationValue,
    LALegacyPreferenceMutationAssignments,
};

__attribute__((visibility("hidden")))
@interface LALegacyBridge : NSObject

#pragma mark - Lifecycle

- (instancetype)initWithBackend:(LAServerBackend *)backend;

#pragma mark - Preference Bridge

- (nullable id)objectForPreferenceKey:(NSString *)key;
- (LALegacyPreferenceMutation)mutationBySettingObject:(nullable id)object forPreferenceKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
