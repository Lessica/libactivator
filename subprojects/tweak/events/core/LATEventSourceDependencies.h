//
//  LATEventSourceDependencies.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATEventDispatching <NSObject>
- (void)dispatchEvent:(LAEvent *)event;
- (void)abortEvent:(LAEvent *)event;
- (void)deactivateEvent:(LAEvent *)event;
@end

@protocol LATEventModeProviding <NSObject>
@property(nonatomic, copy, readonly) NSString *currentEventMode;
@property(nonatomic, copy, readonly) NSString *currentEventModeUnderneathLockScreen;
@end

@protocol LATEventAssignmentQuerying <NSObject>
- (BOOL)hasAssignedListenerForEvent:(LAEvent *)event;
@end

@protocol LATEventDefinitionQuerying <NSObject>
- (BOOL)hasEventDefinitionWithName:(NSString *)eventName;
@end

@protocol LATRuntimeLockStateUpdating <NSObject>
- (void)noteUILocked:(BOOL)uiLocked;
@end

@protocol LATFingerprintGestureCoordinating <NSObject>
- (void)noteDeviceUnlockedAtTimestamp:(NSTimeInterval)timestamp;
- (BOOL)consumePendingSinglePressForSlideInAtTimestamp:(NSTimeInterval)timestamp;
@end

NS_ASSUME_NONNULL_END
