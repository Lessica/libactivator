//
//  LATApplicationLauncher.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationLauncher : NSObject
- (BOOL)enqueueLaunchApplicationWithIdentifier:(NSString *)identifier;
- (BOOL)enqueueLaunchApplicationWithIdentifier:(NSString *)identifier unlockDevice:(BOOL)unlockDevice;
@end

NS_ASSUME_NONNULL_END
