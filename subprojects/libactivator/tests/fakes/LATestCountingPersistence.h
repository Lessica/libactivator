//
//  LATestCountingPersistence.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAPersistence.h"

#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestCountingPersistence : LAPersistence
@property(atomic, assign) NSUInteger saveCount;
@property(atomic, strong) NSDictionary *lastSavedDictionary;
@property(atomic, assign) BOOL failsSaves;
@property(atomic, assign) NSTimeInterval saveDelay;
@property(atomic, strong, nullable) dispatch_semaphore_t saveStartedSemaphore;
@property(atomic, assign) NSUInteger maximumConcurrentSaveCount;
@end

NS_ASSUME_NONNULL_END
