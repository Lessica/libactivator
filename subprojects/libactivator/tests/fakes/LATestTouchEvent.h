//
//  LATestTouchEvent.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestTouchEvent : UIEvent
@property(nonatomic, copy, nullable) NSSet *testTouches;
@property(nonatomic, assign) NSUInteger allTouchesRequestCount;
@end

NS_ASSUME_NONNULL_END
