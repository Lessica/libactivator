//
//  LATestListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestListener.h"

@implementation LATestListener

- (instancetype)init {
    self = [super init];
    if (self) {
        _compatibleModes = @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
        _exclusiveGroups = @[];
    }
    return self;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    self.receiveCount += 1;
    self.lastReceivedEventMode = event.mode;
    self.lastReceivedUserInfo = event.userInfo;
    if (self.handlesReceivedEvents) {
        event.handled = YES;
    }
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    self.abortCount += 1;
}

- (void)activator:(LAActivator *)activator receivePreviewEventForListenerName:(NSString *)listenerName {
    self.previewCount += 1;
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event {
    self.deactivateCount += 1;
    event.handled = YES;
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event {
    self.otherHandledCount += 1;
}

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode {
    self.modeChangeCount += 1;
}

- (BOOL)activator:(LAActivator *)activator
    receiveUnlockingDeviceEvent:(LAEvent *)event
                forListenerName:(NSString *)listenerName {
    self.unlockingCount += 1;
    event.handled = YES;
    return YES;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    return self.compatibleModes;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    return self.exclusiveGroups;
}

- (BOOL)activator:(LAActivator *)activator requiresNeedsPoweredDisplayForListenerName:(NSString *)listenerName {
    return self.needsPoweredDisplay;
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    if ([key isEqualToString:@"requires-no-touch-events"]) {
        return @(self.requiresNoTouchEvents);
    }
    return nil;
}

- (BOOL)activator:(LAActivator *)activator requiresSupportsRemovalForListenerWithName:(NSString *)listenerName {
    return self.supportsRemoval;
}

- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName {
    self.removalRequestCount += 1;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    self.localizedTitleRequestCount += 1;
    return self.localizedTitle;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    self.localizedGroupRequestCount += 1;
    return self.localizedGroup;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    self.localizedDescriptionRequestCount += 1;
    return self.localizedDescription;
}

- (UIImage *)activator:(LAActivator *)activator
    requiresSmallIconForListenerName:(NSString *)listenerName
                               scale:(CGFloat)scale {
    self.smallIconRequestCount += 1;
    return self.smallIconImage;
}

@end
