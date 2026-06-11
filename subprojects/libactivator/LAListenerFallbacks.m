//
//  LAListenerFallbacks.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LAResourceManager.h"

@implementation NSObject (LAListener)

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode {
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self activator:activator receiveEvent:event];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    [self activator:activator abortEvent:event];
}

- (BOOL)activator:(LAActivator *)activator
    receiveUnlockingDeviceEvent:(LAEvent *)event
                forListenerName:(NSString *)listenerName {
    return NO;
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event {
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event {
}

- (void)activator:(LAActivator *)activator receivePreviewEventForListenerName:(NSString *)listenerName {
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event {
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    return [LAResourceManager.sharedManager localizedTitleForListenerName:listenerName];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    return [LAResourceManager.sharedManager localizedDescriptionForListenerName:listenerName];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    return [LAResourceManager.sharedManager localizedGroupForListenerName:listenerName];
}

- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"requires-event"
                                                         forListenerName:listenerName];
    return [value respondsToSelector:@selector(boolValue)] ? @([value boolValue]) : nil;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"compatible-modes"
                                                         forListenerName:listenerName];
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

- (NSNumber *)activator:(LAActivator *)activator
    requiresIsCompatibleWithEventName:(NSString *)eventName
                         listenerName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"incompatible-events"
                                                         forListenerName:listenerName];
    return [value isKindOfClass:NSArray.class] && eventName.length > 0 && [value containsObject:eventName] ? @NO : @YES;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"exclusive-assignment-groups"
                                                         forListenerName:listenerName];
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    if ([key isEqualToString:@"title"]) {
        return [self activator:activator requiresLocalizedTitleForListenerName:listenerName];
    }
    if ([key isEqualToString:@"description"]) {
        return [self activator:activator requiresLocalizedDescriptionForListenerName:listenerName];
    }
    if ([key isEqualToString:@"group"]) {
        return [self activator:activator requiresLocalizedGroupForListenerName:listenerName];
    }
    if ([key isEqualToString:@"requires-event"]) {
        return [self activator:activator requiresRequiresAssignmentForListenerName:listenerName];
    }
    if ([key isEqualToString:@"compatible-modes"]) {
        return [self activator:activator requiresCompatibleEventModesForListenerWithName:listenerName];
    }
    return [LAResourceManager.sharedManager infoDictionaryValueOfKey:key forListenerName:listenerName];
}

- (BOOL)activator:(LAActivator *)activator requiresNeedsPoweredDisplayForListenerName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"needs-powered-display"
                                                         forListenerName:listenerName];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName {
    CGFloat scale = 1.0f;
    return [self activator:activator requiresSmallIconDataForListenerName:listenerName scale:&scale];
}

- (NSData *)activator:(LAActivator *)activator
    requiresSmallIconDataForListenerName:(NSString *)listenerName
                                   scale:(CGFloat *)scale {
    return [LAResourceManager.sharedManager iconDataForListenerName:listenerName small:YES scale:scale];
}

- (UIImage *)activator:(LAActivator *)activator
    requiresSmallIconForListenerName:(NSString *)listenerName
                               scale:(CGFloat)scale {
    return nil;
}

- (id)activator:(LAActivator *)activator requiresGlyphImageDescriptorForListenerName:(NSString *)listenerName {
    return nil;
}

- (BOOL)activator:(LAActivator *)activator requiresSupportsRemovalForListenerWithName:(NSString *)listenerName {
    id value = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"supports-removal"
                                                         forListenerName:listenerName];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName {
}

- (NSString *)activator:(LAActivator *)activator
    requiresConfigurationViewControllerClassNameForListenerWithName:(NSString *)listenerName
                                                             bundle:(NSBundle **)outBundle {
    NSString *className = [LAResourceManager.sharedManager infoDictionaryValueOfKey:@"configuration"
                                                                    forListenerName:listenerName];
    if (![className isKindOfClass:NSString.class] || className.length == 0) {
        return nil;
    }
    if (outBundle) {
        *outBundle = [LAResourceManager.sharedManager listenerBundleForName:listenerName];
    }
    return className;
}

- (id)activator:(LAActivator *)activator requestsConfigurationForListenerWithName:(NSString *)listenerName {
    return nil;
}

- (void)activator:(LAActivator *)activator
    didSaveNewConfiguration:(id)configuration
        forListenerWithName:(NSString *)listenerName {
}

@end
