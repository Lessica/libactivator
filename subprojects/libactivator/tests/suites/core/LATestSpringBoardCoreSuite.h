//
//  LATestSpringBoardCoreSuite.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;
@class LATestRecorder;

@interface LATestSpringBoardCoreSuite : NSObject
+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END

