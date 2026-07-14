//
//  LAListenerMetadataCache.m
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAListenerMetadataCache.h"

#import <os/lock.h>

static NSUInteger const LAListenerMetadataCacheCountLimit = 512;

@interface LAListenerMetadataCache () {
    os_unfair_lock _stateLock;
    NSUInteger _generation;
}

// Underlying caches
@property(nonatomic, strong) NSCache<NSString *, id> *smallIcons;
@property(nonatomic, strong) NSCache<NSString *, id> *localizedTitles;
@property(nonatomic, strong) NSCache<NSString *, id> *localizedGroups;
@property(nonatomic, strong) NSCache<NSString *, id> *localizedDescriptions;

@end

@implementation LAListenerMetadataCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _stateLock = OS_UNFAIR_LOCK_INIT;
        _smallIcons = [self cacheWithName:@"libactivator.listener-metadata.small-icons"];
        _localizedTitles = [self cacheWithName:@"libactivator.listener-metadata.localized-titles"];
        _localizedGroups = [self cacheWithName:@"libactivator.listener-metadata.localized-groups"];
        _localizedDescriptions = [self cacheWithName:@"libactivator.listener-metadata.localized-descriptions"];
    }
    return self;
}

- (NSCache<NSString *, id> *)cacheWithName:(NSString *)name {
    NSCache<NSString *, id> *cache = [[NSCache alloc] init];
    cache.name = name;
    cache.countLimit = LAListenerMetadataCacheCountLimit;
    return cache;
}

- (void)removeAllObjects {
    os_unfair_lock_lock(&_stateLock);
    _generation += 1;
    [self.smallIcons removeAllObjects];
    [self.localizedTitles removeAllObjects];
    [self.localizedGroups removeAllObjects];
    [self.localizedDescriptions removeAllObjects];
    os_unfair_lock_unlock(&_stateLock);
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName resolver:(UIImage * (^)(void))resolver {
    return [self cachedObjectForListenerName:listenerName cache:self.smallIcons resolver:resolver];
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName resolver:(NSString * (^)(void))resolver {
    return [self cachedObjectForListenerName:listenerName cache:self.localizedTitles resolver:resolver];
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName resolver:(NSString * (^)(void))resolver {
    return [self cachedObjectForListenerName:listenerName cache:self.localizedGroups resolver:resolver];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName resolver:(NSString * (^)(void))resolver {
    return [self cachedObjectForListenerName:listenerName cache:self.localizedDescriptions resolver:resolver];
}

- (id)cachedObjectForListenerName:(NSString *)listenerName
                            cache:(NSCache<NSString *, id> *)cache
                         resolver:(id (^)(void))resolver {
    if (listenerName.length == 0) {
        return resolver ? resolver() : nil;
    }

    os_unfair_lock_lock(&_stateLock);
    NSUInteger generation = _generation;
    id cachedObject = [cache objectForKey:listenerName];
    os_unfair_lock_unlock(&_stateLock);
    if (cachedObject) {
        return cachedObject == NSNull.null ? nil : cachedObject;
    }

    id resolvedObject = resolver ? resolver() : nil;
    os_unfair_lock_lock(&_stateLock);
    if (_generation == generation) {
        [cache setObject:resolvedObject ?: NSNull.null forKey:listenerName];
    }
    os_unfair_lock_unlock(&_stateLock);

    return resolvedObject;
}

@end
