//
//  LADefaultEventDataSource.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LADefaultEventDataSource.h"

#import "LAActivatorResourceManager.h"

#import <dispatch/dispatch.h>

@implementation LADefaultEventDataSource

- (void)registerAvailableEventsWithActivator:(LAActivator *)activator {
    for (NSString *eventName in [LAActivatorResourceManager.sharedManager availableEventNames]) {
        if (![activator hasEventWithName:eventName]) {
            [activator registerEventDataSource:self forEventName:eventName];
        }
    }
}

#pragma mark - LAEventDataSource

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    return [LAActivatorResourceManager.sharedManager localizedTitleForEventName:eventName];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    return [LAActivatorResourceManager.sharedManager localizedGroupForEventName:eventName];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    return [LAActivatorResourceManager.sharedManager localizedDescriptionForEventName:eventName];
}

- (BOOL)eventWithNameIsHidden:(NSString *)eventName {
    return [[LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"hidden"] boolValue];
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName {
    id value = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"requires-event"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : YES;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    NSArray *modes =
        [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"compatible-modes"];
    if ([modes isKindOfClass:NSArray.class] && eventMode.length > 0) {
        return [modes containsObject:eventMode];
    }
    return YES;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    return [[LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName][@"supports-removal"]
        boolValue];
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

- (NSString *)configurationViewControllerClassNameForEventWithName:(NSString *)eventName bundle:(NSBundle **)bundle {
    NSDictionary *info = [LAActivatorResourceManager.sharedManager eventInfoDictionaryForName:eventName];
    NSString *className = [info[@"settings-view-controller-class"] isKindOfClass:NSString.class]
                              ? info[@"settings-view-controller-class"]
                              : info[@"configuration"];
    if (className.length > 0 && bundle) {
        *bundle = [LAActivatorResourceManager.sharedManager configurationBundleForEventName:eventName];
    }
    return className;
}

@end
