//
//  LAActivatorResourceManager.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorResourceManager.h"

#import <dispatch/dispatch.h>
#import <roothide.h>

@interface LAActivatorResourceManager ()
@property(nonatomic, strong) NSBundle *cachedSupportBundle;
@property(nonatomic, strong) NSMutableDictionary *eventBundles;
@property(nonatomic, strong) NSMutableDictionary *listenerBundles;
@property(nonatomic, strong) NSDictionary *bundledListenerInfo;
@end

@implementation LAActivatorResourceManager

#pragma mark - Lifecycle

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static LAActivatorResourceManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _eventBundles = [[NSMutableDictionary alloc] init];
        _listenerBundles = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Paths

- (NSString *)supportDirectoryPath {
    return jbroot(@"/Library/Activator");
}

- (NSString *)eventsDirectoryPath {
    return [[self supportDirectoryPath] stringByAppendingPathComponent:@"Events"];
}

- (NSString *)listenersDirectoryPath {
    return [[self supportDirectoryPath] stringByAppendingPathComponent:@"Listeners"];
}

#pragma mark - Bundles

- (NSBundle *)supportBundle {
    if (!self.cachedSupportBundle) {
        self.cachedSupportBundle = [NSBundle bundleWithPath:[self supportDirectoryPath]];
    }
    return self.cachedSupportBundle;
}

- (NSBundle *)eventBundleForName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }

    NSBundle *bundle = self.eventBundles[eventName];
    if (!bundle) {
        NSString *path = [[self eventsDirectoryPath] stringByAppendingPathComponent:eventName];
        bundle = [NSBundle bundleWithPath:path];
        if (bundle) {
            self.eventBundles[eventName] = bundle;
        }
    }
    return bundle;
}

- (NSDictionary *)eventInfoDictionaryForName:(NSString *)eventName {
    return [[self eventBundleForName:eventName] infoDictionary];
}

- (NSArray *)availableEventNames {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self eventsDirectoryPath] error:nil];
    NSMutableArray *eventNames = [NSMutableArray arrayWithCapacity:contents.count];
    for (NSString *fileName in contents) {
        if ([fileName isKindOfClass:NSString.class] && fileName.length > 0 && ![fileName hasPrefix:@"."] &&
            [self eventBundleIsCompatibleForName:fileName]) {
            [eventNames addObject:fileName];
        }
    }
    return [eventNames sortedArrayUsingSelector:@selector(compare:)];
}

- (BOOL)eventBundleIsCompatibleForName:(NSString *)eventName {
    NSArray *range = [self eventInfoDictionaryForName:eventName][@"CoreFoundationVersion"];
    if (![range isKindOfClass:NSArray.class]) {
        return YES;
    }

    if (range.count == 0 || range.count > 2) {
        return NO;
    }
    if (range.count > 0 && [range[0] respondsToSelector:@selector(doubleValue)] &&
        [range[0] doubleValue] > kCFCoreFoundationVersionNumber) {
        return NO;
    }
    if (range.count > 1 && [range[1] respondsToSelector:@selector(doubleValue)] &&
        [range[1] doubleValue] <= kCFCoreFoundationVersionNumber) {
        return NO;
    }
    return YES;
}

- (NSBundle *)listenerBundleForName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return nil;
    }

    NSBundle *bundle = self.listenerBundles[listenerName];
    if (!bundle) {
        NSString *path = [[self listenersDirectoryPath] stringByAppendingPathComponent:listenerName];
        bundle = [NSBundle bundleWithPath:path];
        if (bundle) {
            self.listenerBundles[listenerName] = bundle;
        }
    }
    return bundle;
}

- (NSDictionary *)bundledListenerInfo {
    if (!_bundledListenerInfo) {
        NSString *path = [[self listenersDirectoryPath] stringByAppendingPathComponent:@"bundled.plist"];
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
        _bundledListenerInfo = [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
    }
    return _bundledListenerInfo;
}

- (NSDictionary *)listenerInfoDictionaryForName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return nil;
    }

    NSDictionary *dictionary = self.bundledListenerInfo[listenerName];
    if ([dictionary isKindOfClass:NSDictionary.class]) {
        return dictionary;
    }
    return [[self listenerBundleForName:listenerName] infoDictionary];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerName:(NSString *)listenerName {
    if (key.length == 0) {
        return nil;
    }
    return [self listenerInfoDictionaryForName:listenerName][key];
}

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value {
    if (key.length == 0) {
        return value ?: @"";
    }

    NSString *localized = [[self supportBundle] localizedStringForKey:key value:value table:nil];
    if (localized.length > 0) {
        return localized;
    }
    if (value.length > 0) {
        return value;
    }
    return key;
}

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value bundle:(NSBundle *)bundle {
    if (key.length == 0) {
        return value ?: @"";
    }

    NSString *localized = [bundle localizedStringForKey:key value:value table:nil];
    if (localized.length > 0) {
        return localized;
    }
    if (value.length > 0) {
        return value;
    }
    return key;
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    NSDictionary *info = [self eventInfoDictionaryForName:eventName];
    NSString *title = [info[@"title"] isKindOfClass:NSString.class] ? info[@"title"] : eventName;
    NSString *bundleTitle = [self localizedStringForKey:title value:title bundle:[self eventBundleForName:eventName]];
    return [self localizedStringForKey:[@"EVENT_TITLE_" stringByAppendingString:eventName ?: @""]
                                 value:bundleTitle ?: eventName];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    NSDictionary *info = [self eventInfoDictionaryForName:eventName];
    NSString *group = [info[@"group"] isKindOfClass:NSString.class] ? info[@"group"] : @"";
    if (group.length == 0) {
        return @"";
    }

    NSString *bundleGroup = [self localizedStringForKey:group value:group bundle:[self eventBundleForName:eventName]];
    return [self localizedStringForKey:[@"EVENT_GROUP_TITLE_" stringByAppendingString:group]
                                 value:bundleGroup ?: group];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    NSDictionary *info = [self eventInfoDictionaryForName:eventName];
    NSString *description = [info[@"description"] isKindOfClass:NSString.class] ? info[@"description"] : nil;
    NSString *overrideKey = [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName ?: @""];
    if (description.length > 0) {
        NSString *bundleDescription = [self localizedStringForKey:description
                                                            value:description
                                                           bundle:[self eventBundleForName:eventName]];
        return [self localizedStringForKey:overrideKey value:bundleDescription];
    }

    NSString *localized = [[self supportBundle] localizedStringForKey:overrideKey value:nil table:nil];
    return [localized isEqualToString:overrideKey] ? nil : localized;
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName {
    NSString *title = [self infoDictionaryValueOfKey:@"title" forListenerName:listenerName];
    if (![title isKindOfClass:NSString.class] || title.length == 0) {
        title = listenerName;
    }

    NSString *bundleTitle = [self localizedStringForKey:title
                                                  value:title
                                                 bundle:[self listenerBundleForName:listenerName]];
    return [self localizedStringForKey:[@"LISTENER_TITLE_" stringByAppendingString:listenerName ?: @""]
                                 value:bundleTitle ?: listenerName];
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName {
    NSString *group = [self infoDictionaryValueOfKey:@"group" forListenerName:listenerName];
    if (![group isKindOfClass:NSString.class] || group.length == 0) {
        return @"";
    }

    NSString *bundleGroup = [self localizedStringForKey:group
                                                  value:group
                                                 bundle:[self listenerBundleForName:listenerName]];
    return [self localizedStringForKey:[@"LISTENER_GROUP_TITLE_" stringByAppendingString:group]
                                 value:bundleGroup ?: group];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName {
    NSString *description = [self infoDictionaryValueOfKey:@"description" forListenerName:listenerName];
    NSString *overrideKey = [@"LISTENER_DESCRIPTION_" stringByAppendingString:listenerName ?: @""];
    if ([description isKindOfClass:NSString.class] && description.length > 0) {
        NSString *bundleDescription = [self localizedStringForKey:description
                                                            value:description
                                                           bundle:[self listenerBundleForName:listenerName]];
        return [self localizedStringForKey:overrideKey value:bundleDescription];
    }

    NSString *localized = [[self supportBundle] localizedStringForKey:overrideKey value:nil table:nil];
    return [localized isEqualToString:overrideKey] ? nil : localized;
}

#pragma mark - Icons

- (NSArray *)iconResourceNamesForSmallIcon:(BOOL)small scale:(CGFloat)scale {
    NSString *base = small ? @"icon-small" : @"icon";
    NSString *capitalizedBase = small ? @"Icon-small" : @"Icon";
    NSString *fallback = small ? @"icon-small-fallback" : @"icon-fallback";
    NSString *capitalizedFallback = small ? @"Icon-small-fallback" : @"Icon-fallback";
    if (scale != 1.0f) {
        NSString *suffix = [NSString stringWithFormat:@"@%.0fx", scale];
        return @[
            [base stringByAppendingString:suffix],
            [capitalizedBase stringByAppendingString:suffix],
            [fallback stringByAppendingString:suffix],
            [capitalizedFallback stringByAppendingString:suffix],
            base,
            capitalizedBase,
            fallback,
            capitalizedFallback,
        ];
    }
    return @[ base, capitalizedBase, fallback, capitalizedFallback ];
}

- (NSData *)iconDataForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat *)scale {
    NSBundle *bundle = [self listenerBundleForName:listenerName];
    if (!bundle) {
        return nil;
    }

    CGFloat requestedScale = scale ? *scale : 1.0f;
    for (NSString *resourceName in [self iconResourceNamesForSmallIcon:small scale:requestedScale]) {
        NSString *path = [bundle pathForResource:resourceName ofType:@"png"];
        NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
        if (data.length > 0) {
            if (scale && requestedScale != 1.0f && ![resourceName containsString:@"@"]) {
                *scale = 1.0f;
            }
            return data;
        }
    }
    return nil;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat)scale {
    CGFloat actualScale = scale;
    NSData *data = [self iconDataForListenerName:listenerName small:small scale:&actualScale];
    if (data.length == 0) {
        return nil;
    }

    UIImage *image = [UIImage imageWithData:data scale:actualScale > 0.0f ? actualScale : 1.0f];
    return image;
}

@end
