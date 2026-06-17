//
//  LATCameraActionListener.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"

@class LATApplicationLauncher;
@class LATBuiltInRegistry;

NS_ASSUME_NONNULL_BEGIN

@interface LATCameraActionListener : NSObject <LAListener, LATBuiltInListenerRegistrant>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
                        registry:(nullable LATBuiltInRegistry *)registry NS_DESIGNATED_INITIALIZER;

+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
- (BOOL)listenerNameMatchesRequiredMetadata:(NSString *)listenerName activator:(nullable LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
