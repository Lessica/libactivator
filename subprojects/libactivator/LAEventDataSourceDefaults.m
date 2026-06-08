//
//  LAEventDataSourceDefaults.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import "LAActivatorResourceManager.h"

@implementation NSObject (LAEventDataSource)

- (BOOL)eventWithNameIsHidden:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"hidden"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"requires-event"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : YES;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"compatible-modes"];
    if ([value isKindOfClass:NSArray.class] && eventMode.length > 0) {
        return [value containsObject:eventMode];
    }
    return YES;
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
    id value =
        [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"supports-unlocking-device"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSString *)assignmentWarningForEventWithName:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"assignment-warning"];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

- (BOOL)eventWithNameIsUnprotected:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"is-unprotected"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"supports-removal"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (void)removeEventWithName:(NSString *)eventName {
}

- (NSString *)configurationViewControllerClassNameForEventWithName:(NSString *)eventName bundle:(NSBundle **)bundle {
    NSString *className = [LAActivatorResourceManager.sharedManager
        eventInfoDictionaryForName:eventName][@"settings-view-controller-class"];
    if (![className isKindOfClass:NSString.class] || className.length == 0) {
        className = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"configuration"];
    }
    if (![className isKindOfClass:NSString.class] || className.length == 0) {
        return nil;
    }
    if (bundle) {
        *bundle = [LAActivatorResourceManager.sharedManager configurationBundleForEventName:eventName];
    }
    return className;
}

- (id)configurationForEventWithName:(NSString *)eventName {
    return nil;
}

- (void)eventWithName:(NSString *)eventName didSaveNewConfiguration:(id)configuration {
}

@end
