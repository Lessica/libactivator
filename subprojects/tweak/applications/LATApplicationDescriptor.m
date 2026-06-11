//
//  LATApplicationDescriptor.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATApplicationDescriptor.h"

#import <UIKit/UIKit.h>

@interface LSApplicationRecord : NSObject
@property(nonatomic, readonly) NSArray *appTags;
@property(nonatomic, readonly, getter=isLaunchProhibited) BOOL launchProhibited;
@end

@interface LSApplicationProxy : NSObject
@property(nonatomic, readonly) NSString *applicationIdentifier;
@property(nonatomic, readonly) NSString *bundleIdentifier;
@property(nonatomic, readonly) NSURL *bundleURL;
@property(nonatomic, readonly) NSString *localizedName;
@property(nonatomic, readonly) NSString *applicationType;
@property(nonatomic, readonly) NSArray *appTags;
@property(nonatomic, readonly, getter=isLaunchProhibited) BOOL launchProhibited;
- (LSApplicationRecord *)correspondingApplicationRecord;
@end

@implementation LATApplicationDescriptor

#pragma mark - Factories

+ (instancetype)descriptorWithApplicationProxy:(id)applicationProxy {
    if (!applicationProxy) {
        return nil;
    }

    LSApplicationProxy *proxy = (LSApplicationProxy *)applicationProxy;
    NSString *identifier = nil;
    if ([proxy respondsToSelector:@selector(bundleIdentifier)]) {
        identifier = proxy.bundleIdentifier;
    }
    if (identifier.length == 0 && [proxy respondsToSelector:@selector(applicationIdentifier)]) {
        identifier = proxy.applicationIdentifier;
    }
    if (identifier.length == 0) {
        return nil;
    }

    NSArray *appTags = @[];
    if ([proxy respondsToSelector:@selector(appTags)]) {
        appTags = [self normalizedStringArray:proxy.appTags];
    }

    NSArray *recordAppTags = @[];
    BOOL launchProhibited = NO;
    if ([proxy respondsToSelector:@selector(correspondingApplicationRecord)]) {
        LSApplicationRecord *record = [proxy correspondingApplicationRecord];
        if ([record respondsToSelector:@selector(appTags)]) {
            recordAppTags = [self normalizedStringArray:record.appTags];
        }
        if ([record respondsToSelector:@selector(isLaunchProhibited)]) {
            launchProhibited = record.launchProhibited;
        }
    }
    if (!launchProhibited && [proxy respondsToSelector:@selector(isLaunchProhibited)]) {
        launchProhibited = proxy.launchProhibited;
    }

    NSArray *bundleAppTags = @[];
    if ([proxy respondsToSelector:@selector(bundleURL)] && proxy.bundleURL) {
        bundleAppTags = [self bundleAppTagsForBundleURL:proxy.bundleURL];
    }

    NSString *applicationType = @"";
    if ([proxy respondsToSelector:@selector(applicationType)] && [proxy.applicationType isKindOfClass:NSString.class]) {
        applicationType = proxy.applicationType;
    }

    NSString *displayName = [self displayNameForApplicationProxy:proxy fallbackIdentifier:identifier];
    return [self descriptorWithIdentifier:identifier
                              displayName:displayName
                          applicationType:applicationType
                                  appTags:appTags
                            recordAppTags:recordAppTags
                            bundleAppTags:bundleAppTags
                         launchProhibited:launchProhibited];
}

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                             displayName:(NSString *)displayName
                         applicationType:(NSString *)applicationType
                                 appTags:(NSArray<NSString *> *)appTags
                           recordAppTags:(NSArray<NSString *> *)recordAppTags
                           bundleAppTags:(NSArray<NSString *> *)bundleAppTags
                        launchProhibited:(BOOL)launchProhibited {
    return [[self alloc] initWithIdentifier:identifier
                                displayName:displayName
                            applicationType:applicationType
                                    appTags:appTags
                              recordAppTags:recordAppTags
                              bundleAppTags:bundleAppTags
                           launchProhibited:launchProhibited];
}

#pragma mark - Lifecycle

- (instancetype)initWithIdentifier:(NSString *)identifier
                       displayName:(NSString *)displayName
                   applicationType:(NSString *)applicationType
                           appTags:(NSArray<NSString *> *)appTags
                     recordAppTags:(NSArray<NSString *> *)recordAppTags
                     bundleAppTags:(NSArray<NSString *> *)bundleAppTags
                  launchProhibited:(BOOL)launchProhibited {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _displayName = displayName.length > 0 ? [displayName copy] : [identifier copy];
        _applicationType = [applicationType copy] ?: @"";
        _appTags = [appTags copy] ?: @[];
        _recordAppTags = [recordAppTags copy] ?: @[];
        _bundleAppTags = [bundleAppTags copy] ?: @[];
        _launchProhibited = launchProhibited;
    }
    return self;
}

#pragma mark - Classification

- (BOOL)isVisibleApplication {
    return !self.launchProhibited && ![self containsHiddenTag] && ![self isWebClip] &&
           ([self isSystemApplication] || [self isUserApplication]);
}

- (BOOL)isSystemApplication {
    return [self.applicationType isEqualToString:@"System"];
}

- (BOOL)isUserApplication {
    return [self.applicationType isEqualToString:@"User"];
}

- (BOOL)isWebClip {
    return [self.identifier rangeOfString:@"com.apple.webapp" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSString *)applicationGroup {
    if (![self isVisibleApplication]) {
        return nil;
    }
    if ([self isSystemApplication]) {
        return @"System Applications";
    }
    if ([self isUserApplication]) {
        return @"User Applications";
    }
    return nil;
}

#pragma mark - Internal

- (BOOL)containsHiddenTag {
    return [self.class tagArray:self.appTags containsTag:@"hidden"] ||
           [self.class tagArray:self.recordAppTags containsTag:@"hidden"] ||
           [self.class tagArray:self.bundleAppTags containsTag:@"hidden"];
}

#pragma mark - Helpers

+ (NSArray<NSString *> *)normalizedStringArray:(id)value {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSString *> *strings = [[NSMutableArray alloc] init];
    for (id object in (NSArray *)value) {
        if ([object isKindOfClass:NSString.class]) {
            [strings addObject:object];
        }
    }
    return [strings copy];
}

+ (BOOL)tagArray:(NSArray<NSString *> *)tagArray containsTag:(NSString *)tag {
    if (tagArray.count == 0 || tag.length == 0) {
        return NO;
    }

    for (NSString *tagToCheck in tagArray) {
        if ([tagToCheck rangeOfString:tag].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

+ (NSArray<NSString *> *)bundleAppTagsForBundleURL:(NSURL *)bundleURL {
    if (![bundleURL checkResourceIsReachableAndReturnError:nil]) {
        return @[];
    }

    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    return [self normalizedStringArray:[bundle objectForInfoDictionaryKey:@"SBAppTags"]];
}

+ (NSString *)displayNameForApplicationProxy:(LSApplicationProxy *)proxy fallbackIdentifier:(NSString *)identifier {
    NSString *cachedDisplayName = nil;
    @try {
        id value = [proxy valueForKey:@"_localizedName"];
        if ([value isKindOfClass:NSString.class]) {
            cachedDisplayName = value;
        }
    } @catch (__unused NSException *exception) {
        cachedDisplayName = nil;
    }
    if (cachedDisplayName.length > 0) {
        return cachedDisplayName;
    }

    NSString *localizedName = nil;
    if ([proxy respondsToSelector:@selector(bundleURL)] && proxy.bundleURL &&
        [proxy.bundleURL checkResourceIsReachableAndReturnError:nil]) {
        NSBundle *bundle = [NSBundle bundleWithURL:proxy.bundleURL];
        localizedName = [self stringFromBundle:bundle key:@"CFBundleDisplayName"];
        if (localizedName.length == 0) {
            localizedName = [self stringFromBundle:bundle key:@"CFBundleName"];
        }
        if (localizedName.length == 0) {
            localizedName = [self stringFromBundle:bundle key:@"CFBundleExecutable"];
        }
    }

    if (localizedName.length == 0 && [proxy respondsToSelector:@selector(localizedName)] &&
        [proxy.localizedName isKindOfClass:NSString.class]) {
        localizedName = proxy.localizedName;
    }
    if (localizedName.length == 0) {
        localizedName = identifier;
    }
    return localizedName;
}

+ (NSString *)stringFromBundle:(NSBundle *)bundle key:(NSString *)key {
    id value = [bundle objectForInfoDictionaryKey:key];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

@end
