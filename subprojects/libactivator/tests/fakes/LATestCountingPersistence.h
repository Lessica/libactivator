//
//  LATestCountingPersistence.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorPersistence.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATestCountingPersistence : LAActivatorPersistence
@property(nonatomic, assign) NSUInteger saveCount;
@property(nonatomic, strong) NSDictionary *lastSavedDictionary;
@end

NS_ASSUME_NONNULL_END

