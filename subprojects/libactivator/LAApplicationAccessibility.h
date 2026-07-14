//
//  LAApplicationAccessibility.h
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAApplicationAccessibility : NSObject

#pragma mark - State Queries

+ (BOOL)isEnabled;

#pragma mark - State Modification

+ (BOOL)setEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
