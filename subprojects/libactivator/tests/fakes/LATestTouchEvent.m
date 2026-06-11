//
//  LATestTouchEvent.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestTouchEvent.h"

@implementation LATestTouchEvent

- (UIEventType)type {
    return UIEventTypeTouches;
}

- (NSSet *)allTouches {
    return self.testTouches ?: [NSSet set];
}

@end
