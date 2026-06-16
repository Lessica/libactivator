//
//  LATSystemPreviousApplicationController.h
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATApplicationLauncher;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemPreviousApplicationController : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                         runtimeStateSource:(nullable LATRuntimeStateSource *)runtimeStateSource
    NS_DESIGNATED_INITIALIZER;

- (BOOL)launchPreviousApplicationForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
