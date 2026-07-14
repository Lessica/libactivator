//
//  LATestScheduledEventSourceSuite.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATestRecorder;

NS_ASSUME_NONNULL_BEGIN

@interface LATestScheduledEventSourceSuite : NSObject

+ (void)runWithRecorder:(LATestRecorder *)recorder;

@end

NS_ASSUME_NONNULL_END
