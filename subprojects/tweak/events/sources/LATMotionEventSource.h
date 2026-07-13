//
//  LATMotionEventSource.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"
#import "LATEventSourceIngress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATMotionEventSource : NSObject <LATEventSource, LATEventSourceMotionIngress>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider NS_DESIGNATED_INITIALIZER;

- (void)noteMotionEnded:(UIEventSubtype)motion;

#if DEBUG
- (BOOL)la_testingNoteMotionEnded:(UIEventSubtype)motion;
#endif

@end

NS_ASSUME_NONNULL_END
