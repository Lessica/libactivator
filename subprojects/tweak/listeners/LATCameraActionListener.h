//
//  LATCameraActionListener.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LATBuiltInListenerRegistrant.h"
#import "LATSpringBoardInstanceProviding.h"

@class LATApplicationLauncher;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATCameraActionListener : NSObject <LATBuiltInListenerRegistrant>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher
              runtimeStateSource:(LATRuntimeStateSource *)runtimeStateSource
     springBoardInstanceProvider:(nullable id<LATSpringBoardInstanceProviding>)springBoardInstanceProvider
    NS_DESIGNATED_INITIALIZER;

+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
- (BOOL)listenerNameMatchesRequiredMetadata:(NSString *)listenerName activator:(nullable LAActivator *)activator;

@end

NS_ASSUME_NONNULL_END
