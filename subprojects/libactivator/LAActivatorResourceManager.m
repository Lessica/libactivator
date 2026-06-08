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

extern Boolean MGGetBoolAnswer(CFStringRef key);

@interface LAActivatorResourceManager ()
@property(nonatomic, strong) NSBundle *cachedSupportBundle;
@property(nonatomic, strong) NSMutableDictionary *eventBundles;
@property(nonatomic, strong) NSMutableDictionary *listenerBundles;
@property(nonatomic, strong) NSDictionary *bundledEventInfo;
@property(nonatomic, strong) NSDictionary *bundledListenerInfo;
@property(nonatomic, strong) dispatch_queue_t cacheQueue;
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
        _cacheQueue = dispatch_queue_create("libactivator.resources", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
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
    __block NSBundle *bundle = nil;
    dispatch_sync(self.cacheQueue, ^{
        bundle = self.cachedSupportBundle;
    });
    if (bundle) {
        return bundle;
    }

    bundle = [NSBundle bundleWithPath:[self supportDirectoryPath]];
    dispatch_sync(self.cacheQueue, ^{
        if (!self.cachedSupportBundle) {
            self.cachedSupportBundle = bundle;
        }
        bundle = self.cachedSupportBundle;
    });
    return bundle;
}

- (NSBundle *)eventBundleForName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }

    __block NSBundle *bundle = nil;
    dispatch_sync(self.cacheQueue, ^{
        bundle = self.eventBundles[eventName];
    });
    if (bundle) {
        return bundle;
    }

    NSString *path = [[self eventsDirectoryPath] stringByAppendingPathComponent:eventName];
    bundle = [NSBundle bundleWithPath:path];
    if (bundle) {
        dispatch_sync(self.cacheQueue, ^{
            if (!self.eventBundles[eventName]) {
                self.eventBundles[eventName] = bundle;
            }
            bundle = self.eventBundles[eventName];
        });
    }
    return bundle;
}

- (NSBundle *)configurationBundleForEventName:(NSString *)eventName {
    NSDictionary *info = [self eventInfoDictionaryForName:eventName];
    NSString *path = [info[@"settings-view-controller-bundle"] isKindOfClass:NSString.class]
                         ? info[@"settings-view-controller-bundle"]
                         : nil;
    NSString *resolvedPath = [self resolvedPathForResourcePath:path];
    return resolvedPath.length > 0 ? [NSBundle bundleWithPath:resolvedPath] : [self eventBundleForName:eventName];
}

- (NSDictionary *)eventInfoDictionaryForName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }

    NSDictionary *dictionary = self.bundledEventInfo[eventName];
    if ([dictionary isKindOfClass:NSDictionary.class]) {
        return [self resourceInfoDictionaryIsCompatible:dictionary] ? dictionary : nil;
    }
    NSString *path = [[[self eventsDirectoryPath] stringByAppendingPathComponent:eventName]
        stringByAppendingPathComponent:@"Info.plist"];
    dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    return [self resourceInfoDictionaryIsCompatible:dictionary] ? dictionary : nil;
}

- (NSArray *)availableEventNames {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self eventsDirectoryPath] error:nil];
    NSMutableSet *eventNames = [NSMutableSet setWithCapacity:contents.count + self.bundledEventInfo.count];
    for (NSString *eventName in self.bundledEventInfo) {
        if ([eventName isKindOfClass:NSString.class] && eventName.length > 0 &&
            [self eventBundleIsCompatibleForName:eventName]) {
            [eventNames addObject:eventName];
        }
    }
    for (NSString *fileName in contents) {
        if ([fileName isKindOfClass:NSString.class] && fileName.length > 0 && ![fileName hasPrefix:@"."] &&
            [self eventBundleIsCompatibleForName:fileName]) {
            [eventNames addObject:fileName];
        }
    }
    return [eventNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

- (BOOL)eventBundleIsCompatibleForName:(NSString *)eventName {
    return [self eventInfoDictionaryForName:eventName] != nil;
}

- (BOOL)resourceInfoDictionaryIsCompatible:(NSDictionary *)info {
    if (![info isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSArray *range = info[@"CoreFoundationVersion"];
    if (![range isKindOfClass:NSArray.class]) {
        return [self requiredCapabilitiesAreSatisfiedForInfoDictionary:info];
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
    return [self requiredCapabilitiesAreSatisfiedForInfoDictionary:info];
}

- (BOOL)requiredCapabilitiesAreSatisfiedForInfoDictionary:(NSDictionary *)info {
    NSArray *capabilities = info[@"required-capabilities"];
    if (![capabilities isKindOfClass:NSArray.class]) {
        return YES;
    }

    for (id value in capabilities) {
        if (![value isKindOfClass:NSString.class] || [value length] == 0) {
            return NO;
        }
        if (!MGGetBoolAnswer((__bridge CFStringRef)value)) {
            return NO;
        }
    }
    return YES;
}

- (NSDictionary *)bundledEventInfo {
    __block NSDictionary *bundledInfo = nil;
    dispatch_sync(self.cacheQueue, ^{
        bundledInfo = _bundledEventInfo;
    });
    if (bundledInfo) {
        return bundledInfo;
    }

    NSString *path = [[self eventsDirectoryPath] stringByAppendingPathComponent:@"bundled.plist"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    bundledInfo = [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
    dispatch_sync(self.cacheQueue, ^{
        if (!_bundledEventInfo) {
            _bundledEventInfo = bundledInfo;
        }
        bundledInfo = _bundledEventInfo;
    });
    return bundledInfo;
}

- (NSBundle *)listenerBundleForName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return nil;
    }

    __block NSBundle *bundle = nil;
    dispatch_sync(self.cacheQueue, ^{
        bundle = self.listenerBundles[listenerName];
    });
    if (bundle) {
        return bundle;
    }

    NSString *path = [[self listenersDirectoryPath] stringByAppendingPathComponent:listenerName];
    bundle = [NSBundle bundleWithPath:path];
    if (bundle) {
        dispatch_sync(self.cacheQueue, ^{
            if (!self.listenerBundles[listenerName]) {
                self.listenerBundles[listenerName] = bundle;
            }
            bundle = self.listenerBundles[listenerName];
        });
    }
    return bundle;
}

- (NSDictionary *)bundledListenerInfo {
    __block NSDictionary *bundledInfo = nil;
    dispatch_sync(self.cacheQueue, ^{
        bundledInfo = _bundledListenerInfo;
    });
    if (bundledInfo) {
        return bundledInfo;
    }

    NSString *path = [[self listenersDirectoryPath] stringByAppendingPathComponent:@"bundled.plist"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    bundledInfo = [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
    dispatch_sync(self.cacheQueue, ^{
        if (!_bundledListenerInfo) {
            _bundledListenerInfo = bundledInfo;
        }
        bundledInfo = _bundledListenerInfo;
    });
    return bundledInfo;
}

- (NSDictionary *)listenerInfoDictionaryForName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return nil;
    }

    NSDictionary *dictionary = self.bundledListenerInfo[listenerName];
    if ([dictionary isKindOfClass:NSDictionary.class]) {
        return [self resourceInfoDictionaryIsCompatible:dictionary] ? dictionary : nil;
    }
    NSString *path = [[[self listenersDirectoryPath] stringByAppendingPathComponent:listenerName]
        stringByAppendingPathComponent:@"Info.plist"];
    dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    return [self resourceInfoDictionaryIsCompatible:dictionary] ? dictionary : nil;
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
    CGFloat requestedScale = scale ? *scale : 1.0f;
    if (bundle) {
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
    }

    if (small) {
        NSData *data = [self smallIconDataFromMetadataForListenerName:listenerName scale:scale];
        if (data.length > 0) {
            return data;
        }
    }
    return nil;
}

- (NSData *)smallIconDataFromMetadataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale {
    NSArray *paths = [self infoDictionaryValueOfKey:@"small-icons" forListenerName:listenerName];
    if (![paths isKindOfClass:NSArray.class]) {
        return nil;
    }

    CGFloat requestedScale = scale ? *scale : 1.0f;
    for (id value in paths) {
        if (![value isKindOfClass:NSString.class] || [value length] == 0) {
            continue;
        }
        for (NSString *path in [self iconCandidatePathsForPath:value requestedScale:requestedScale]) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data.length > 0) {
                if (scale) {
                    *scale = [self scaleForIconPath:path requestedScale:requestedScale];
                }
                return data;
            }
        }
    }
    return nil;
}

- (NSArray *)iconCandidatePathsForPath:(NSString *)path requestedScale:(CGFloat)requestedScale {
    NSString *resolvedPath = [self resolvedPathForResourcePath:path];
    if (resolvedPath.length == 0) {
        return @[];
    }
    if (requestedScale == 1.0f) {
        return @[ resolvedPath ];
    }

    NSString *extension = resolvedPath.pathExtension;
    NSString *basePath = extension.length > 0 ? [resolvedPath stringByDeletingPathExtension] : resolvedPath;
    NSString *scaledPath = [basePath stringByAppendingFormat:@"@%.0fx", requestedScale];
    if (extension.length > 0) {
        scaledPath = [scaledPath stringByAppendingPathExtension:extension];
    }
    return @[ scaledPath, resolvedPath ];
}

- (CGFloat)scaleForIconPath:(NSString *)path requestedScale:(CGFloat)requestedScale {
    NSString *lastPathComponent = path.lastPathComponent;
    if ([lastPathComponent containsString:@"@3x"]) {
        return 3.0f;
    }
    if ([lastPathComponent containsString:@"@2x"]) {
        return 2.0f;
    }
    return requestedScale == 1.0f ? 1.0f : 1.0f;
}

- (NSString *)resolvedPathForResourcePath:(NSString *)path {
    if (path.length == 0) {
        return nil;
    }
    if (![path hasPrefix:@"/"]) {
        return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
    }

    NSString *jailbreakPath = jbroot(path);
    if ([NSFileManager.defaultManager fileExistsAtPath:jailbreakPath]) {
        return jailbreakPath;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : nil;
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
