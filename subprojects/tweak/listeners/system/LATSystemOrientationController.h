//
//  LATSystemOrientationController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemOrientationController : NSObject
- (BOOL)rotateToOrientation:(NSInteger)orientation listenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
