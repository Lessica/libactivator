//
//  LATestSimpleAbortListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestSimpleAbortListener.h"

@implementation LATestSimpleAbortListener

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event {
    self.abortCount += 1;
}

@end

