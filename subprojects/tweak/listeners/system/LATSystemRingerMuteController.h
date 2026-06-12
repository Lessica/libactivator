//
//  LATSystemRingerMuteController.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATBuiltInRegistry;
@class LATSystemActionCommand;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemRingerMuteController : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRegistry:(nullable LATBuiltInRegistry *)registry NS_DESIGNATED_INITIALIZER;

- (BOOL)applyCommand:(LATSystemActionCommand *)command;

@end

NS_ASSUME_NONNULL_END
