//
//  LATEdgeGestureEventSource.m
//  libactivator
//
//  Created by OpenAI on 6/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEdgeGestureEventSource.h"

#import "LATEdgeGestureClassifier.h"
#import "LATQueueAssertions.h"

#import <HBLog.h>

@interface LATEdgeGestureEventSource ()

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong) LATEdgeGestureClassifier *classifier;
#if LA_TESTING
@property(nonatomic, assign) NSTimeInterval lastSideDiagnosticTimestamp;
#endif

@end

@implementation LATEdgeGestureEventSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _classifier = [[LATEdgeGestureClassifier alloc] init];
    }
    return self;
}

- (void)start {
    LATAssertMainQueue();
    if (self.started) {
        return;
    }
    self.started = YES;
}

- (void)noteSystemGestureWindow:(UIWindow *)window event:(UIEvent *)event {
    LATAssertMainQueue();
    if (!self.started || !window || !event) {
        return;
    }

    NSArray<NSDictionary<NSString *, id> *> *snapshots = [self touchSnapshotsFromEvent:event inWindow:window];
    if (snapshots.count == 0) {
        return;
    }

#if LA_TESTING
    [self logSideGestureDiagnosticForTouchSnapshots:snapshots bounds:window.bounds timestamp:event.timestamp];
#endif

    NSString *eventName = [self.classifier updateWithTouchSnapshots:snapshots
                                                             bounds:window.bounds
                                                          timestamp:event.timestamp];
    if (eventName.length > 0) {
        HBLogInfo(@"Classified edge gesture event=%@ touchCount=%lu bounds=%@",
                  eventName,
                  (unsigned long)snapshots.count,
                  NSStringFromCGRect(window.bounds));
    }
}

- (NSArray<NSDictionary<NSString *, id> *> *)touchSnapshotsFromEvent:(UIEvent *)event inWindow:(UIWindow *)window {
    NSMutableArray<NSDictionary<NSString *, id> *> *snapshots = [[NSMutableArray alloc] init];
    for (UITouch *touch in event.allTouches) {
        CGPoint location = [touch locationInView:window];
        [snapshots addObject:@{
            LATEdgeGestureTouchIdentifierKey : [NSValue valueWithNonretainedObject:touch],
            LATEdgeGestureTouchPhaseKey : @(touch.phase),
            LATEdgeGestureTouchLocationKey : [NSValue valueWithCGPoint:location],
        }];
    }
    return snapshots;
}

#if LA_TESTING
- (void)logSideGestureDiagnosticForTouchSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots
                                           bounds:(CGRect)bounds
                                        timestamp:(NSTimeInterval)timestamp {
    if (CGRectIsEmpty(bounds) || timestamp - self.lastSideDiagnosticTimestamp < 0.03) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat sideDiagnosticBand = MIN(MAX(width * 0.15, 80.0), 140.0);
    NSUInteger activeTouchCount = 0;
    CGFloat minX = CGFLOAT_MAX;
    CGFloat maxX = -CGFLOAT_MAX;
    CGFloat xTotal = 0.0;
    CGFloat yTotal = 0.0;
    NSMutableArray<NSString *> *touchDescriptions = [[NSMutableArray alloc] init];

    for (NSDictionary<NSString *, id> *snapshot in snapshots) {
        NSNumber *phaseNumber = snapshot[LATEdgeGestureTouchPhaseKey];
        NSValue *locationValue = snapshot[LATEdgeGestureTouchLocationKey];
        if (!phaseNumber || !locationValue) {
            continue;
        }

        NSInteger phase = phaseNumber.integerValue;
        CGPoint location = locationValue.CGPointValue;
        [touchDescriptions addObject:[NSString stringWithFormat:@"phase=%ld location=%@", (long)phase,
                                                                NSStringFromCGPoint(location)]];
        if (phase == 3 || phase == 4) {
            continue;
        }

        activeTouchCount++;
        minX = MIN(minX, location.x);
        maxX = MAX(maxX, location.x);
        xTotal += location.x;
        yTotal += location.y;
    }

    if (activeTouchCount == 0) {
        return;
    }

    BOOL nearLeftSide = minX <= sideDiagnosticBand;
    BOOL nearRightSide = maxX >= width - sideDiagnosticBand;
    if (!nearLeftSide && !nearRightSide) {
        return;
    }

    self.lastSideDiagnosticTimestamp = timestamp;
    CGPoint centroid = CGPointMake(xTotal / (CGFloat)activeTouchCount, yTotal / (CGFloat)activeTouchCount);
    HBLogInfo(@"Edge gesture diagnostic activeTouchCount=%lu totalTouchCount=%lu minX=%.1f maxX=%.1f centroid=%@ "
              @"bounds=%@ touches=[%@]",
              (unsigned long)activeTouchCount,
              (unsigned long)snapshots.count,
              minX,
              maxX,
              NSStringFromCGPoint(centroid),
              NSStringFromCGRect(bounds),
              [touchDescriptions componentsJoinedByString:@"; "]);
}
#endif

@end
