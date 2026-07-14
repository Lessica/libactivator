//
//  LATGestureBarEventSource.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LATEventSource.h"
#import "LATEventSourceDependencies.h"
#import "LATEventSourceIngress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATGestureBarEventSource : NSObject <LATEventSource, LATEventSourceGestureBarIngress>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider NS_DESIGNATED_INITIALIZER;

- (void)noteGestureBarDoubleTapRecognizerDidLoad:(UITapGestureRecognizer *)recognizer;

#if DEBUG
- (BOOL)la_testingHandleTapState:(UIGestureRecognizerState)state location:(CGPoint)location bounds:(CGRect)bounds;
- (NSUInteger)la_testingKnownRecognizerCount;
- (BOOL)la_testingIsAttachedToRecognizer:(UITapGestureRecognizer *)recognizer;
#endif

@end

NS_ASSUME_NONNULL_END
