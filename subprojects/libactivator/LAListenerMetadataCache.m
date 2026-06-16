//
//  LAListenerMetadataCache.m
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAListenerMetadataCache.h"

#import <os/lock.h>

@interface LAListenerMetadataCache () {
    os_unfair_lock _cacheLock;
}

// Underlying caches
@property(nonatomic, strong) NSMutableDictionary *smallIcons;
@property(nonatomic, strong) NSMutableDictionary *localizedTitles;
@property(nonatomic, strong) NSMutableDictionary *localizedGroups;
@property(nonatomic, strong) NSMutableDictionary *localizedDescriptions;

@end

@implementation LAListenerMetadataCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _smallIcons = [[NSMutableDictionary alloc] init];
        _localizedTitles = [[NSMutableDictionary alloc] init];
        _localizedGroups = [[NSMutableDictionary alloc] init];
        _localizedDescriptions = [[NSMutableDictionary alloc] init];
        _cacheLock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

- (void)removeAllObjects {
    os_unfair_lock_lock(&_cacheLock);
    [self.smallIcons removeAllObjects];
    [self.localizedTitles removeAllObjects];
    [self.localizedGroups removeAllObjects];
    [self.localizedDescriptions removeAllObjects];
    os_unfair_lock_unlock(&_cacheLock);
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
                            cache:(NSMutableDictionary *)cache
                         resolver:(id (^)(void))resolver {
    if (listenerName.length == 0) {
        return resolver ? resolver() : nil;
    }

    os_unfair_lock_lock(&_cacheLock);
    id cachedObject = cache[listenerName];
    os_unfair_lock_unlock(&_cacheLock);

    if (cachedObject) {
        return cachedObject == NSNull.null ? nil : cachedObject;
    }

    id resolvedObject = resolver ? resolver() : nil;

    os_unfair_lock_lock(&_cacheLock);
    cache[listenerName] = resolvedObject ?: NSNull.null;
    os_unfair_lock_unlock(&_cacheLock);

    return resolvedObject;
}

@end
