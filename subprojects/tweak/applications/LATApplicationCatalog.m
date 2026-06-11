//
//  LATApplicationCatalog.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATApplicationCatalog.h"

#import "LATApplicationDescriptor.h"

#import <HBLog.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@end

@implementation LATApplicationCatalog

#pragma mark - Public API

- (NSArray<LATApplicationDescriptor *> *)visibleApplicationDescriptors {
    NSArray *applicationProxies = [self allInstalledApplicationProxies];
    NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier =
        [[NSMutableDictionary alloc] initWithCapacity:applicationProxies.count];

    for (id applicationProxy in applicationProxies) {
        LATApplicationDescriptor *descriptor =
            [LATApplicationDescriptor descriptorWithApplicationProxy:applicationProxy];
        if (![descriptor isVisibleApplication]) {
            continue;
        }
        descriptorsByIdentifier[descriptor.identifier] = descriptor;
    }

    return [[descriptorsByIdentifier allValues] sortedArrayUsingComparator:^NSComparisonResult(
                                                    LATApplicationDescriptor *first, LATApplicationDescriptor *second) {
        return [first.identifier compare:second.identifier];
    }];
}

- (LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier {
    if (identifier.length == 0) {
        return nil;
    }

    LSApplicationProxy *applicationProxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    LATApplicationDescriptor *descriptor = [LATApplicationDescriptor descriptorWithApplicationProxy:applicationProxy];
    return [descriptor isVisibleApplication] ? descriptor : nil;
}

#pragma mark - Internal

- (NSArray *)allInstalledApplicationProxies {
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];

    if ([workspace respondsToSelector:@selector(allInstalledApplications)]) {
        NSArray *applications = [workspace allInstalledApplications];
        return [applications isKindOfClass:NSArray.class] ? applications : @[];
    }

    HBLogError(@"LSApplicationWorkspace does not support installed application enumeration");
    return @[];
}

@end
