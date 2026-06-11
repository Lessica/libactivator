//
//  LATestTouchActivitySuite.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LATestRecorder;

@interface LATestTouchActivitySuite : NSObject
+ (void)runWithRecorder:(LATestRecorder *)recorder;
@end

NS_ASSUME_NONNULL_END
