//
//  LATApplicationDescriptor.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATApplicationDescriptor.h"

@interface LSApplicationRecord : NSObject
@property(nonatomic, readonly) NSArray *appTags;
@property(nonatomic, readonly, getter=isLaunchProhibited) BOOL launchProhibited;
@end

@interface LSApplicationProxy : NSObject
@property(nonatomic, readonly) NSString *applicationIdentifier;
@property(nonatomic, readonly) NSString *bundleIdentifier;
@property(nonatomic, readonly) NSString *localizedName;
@property(nonatomic, readonly) NSString *applicationType;
@property(nonatomic, readonly) NSArray *appTags;
@property(nonatomic, readonly, getter=isLaunchProhibited) BOOL launchProhibited;
- (LSApplicationRecord *)correspondingApplicationRecord;
@end

@interface LATApplicationDescriptor ()
@property(nonatomic, strong) LSApplicationProxy *applicationProxy;
@end

@implementation LATApplicationDescriptor

@synthesize displayName = _displayName;
@synthesize bundleAppTags = _bundleAppTags;

#pragma mark - Factories

+ (instancetype)descriptorWithApplicationProxy:(LSApplicationProxy *)applicationProxy {
    if (!applicationProxy) {
        return nil;
    }

    LSApplicationProxy *proxy = applicationProxy;
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

    NSString *applicationType = @"";
    if ([proxy respondsToSelector:@selector(applicationType)] && [proxy.applicationType isKindOfClass:NSString.class]) {
        applicationType = proxy.applicationType;
    }

    NSArray *appTags = @[];
    NSArray *recordAppTags = @[];
    BOOL launchProhibited = NO;
    BOOL mayRegisterDynamicListener =
        ([applicationType isEqualToString:@"System"] || [applicationType isEqualToString:@"User"]) &&
        [identifier rangeOfString:@"com.apple.webapp" options:NSCaseInsensitiveSearch].location == NSNotFound;
    if (mayRegisterDynamicListener) {
        if ([proxy respondsToSelector:@selector(appTags)]) {
            appTags = [self normalizedStringArray:proxy.appTags];
        }

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
    }

    LATApplicationDescriptor *descriptor = [[self alloc] initWithIdentifier:identifier
                                                                displayName:nil
                                                            applicationType:applicationType
                                                                    appTags:appTags
                                                              recordAppTags:recordAppTags
                                                              bundleAppTags:@[]
                                                           launchProhibited:launchProhibited];
    descriptor.applicationProxy = proxy;
    return descriptor;
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
        _displayName = [displayName copy];
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
    if (![self isSystemApplication] && ![self isUserApplication]) {
        return NO;
    }
    if ([self isWebClip] || self.launchProhibited) {
        return NO;
    }
    return ![self containsHiddenTag];
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

- (NSString *)displayName {
    if (_displayName.length > 0) {
        return _displayName;
    }

    _displayName = [[self.class displayNameForApplicationProxy:self.applicationProxy
                                            fallbackIdentifier:self.identifier] copy];
    return _displayName;
}

- (BOOL)containsHiddenTag {
    return [self.class tagArray:self.appTags containsTag:@"hidden"] ||
           [self.class tagArray:self.recordAppTags containsTag:@"hidden"] ||
           [self.class tagArray:self.bundleAppTags containsTag:@"hidden"];
}

#pragma mark - Helpers

+ (NSArray<NSString *> *)normalizedStringArray:(NSArray *)value {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSString *> *strings = [[NSMutableArray alloc] init];
    for (NSString *object in value) {
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

+ (NSString *)displayNameForApplicationProxy:(LSApplicationProxy *)proxy fallbackIdentifier:(NSString *)identifier {
    NSString *localizedName = nil;
    if ([proxy respondsToSelector:@selector(localizedName)]) {
        NSString *value = proxy.localizedName;
        if ([value isKindOfClass:NSString.class]) {
            localizedName = value;
        }
    }
    if (localizedName.length == 0) {
        localizedName = identifier;
    }
    return localizedName;
}

@end
