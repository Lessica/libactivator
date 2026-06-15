//
//  LATEventSourceInterestGate.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LAActivator;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LATEventSourceInterestFamily) {
    LATEventSourceInterestFamilyEdgeGesture,
    LATEventSourceInterestFamilyForceTouch,
    LATEventSourceInterestFamilyStatusBar,
    LATEventSourceInterestFamilyMultiTouch,
};

@interface LATEventSourceInterestGate : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivator:(LAActivator *)activator NS_DESIGNATED_INITIALIZER;

// Lifecycle
// Main-queue confined.
- (void)start;

// Interest
- (BOOL)isInterestedInFamily:(LATEventSourceInterestFamily)family;

#if DEBUG
// Testing hooks
- (void)la_testingInvalidate;
- (NSArray<NSString *> *)la_testingEventNamesForFamily:(LATEventSourceInterestFamily)family;
- (void)la_testingSetEventNames:(NSArray<NSString *> *)eventNames forFamily:(LATEventSourceInterestFamily)family;
#endif

@end

NS_ASSUME_NONNULL_END
