//
//  LAListenerMetadataCache.m
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAListenerMetadataCache.h"

#import <dispatch/dispatch.h>

@interface LAListenerMetadataCache ()

// Underlying caches
@property(nonatomic, strong) NSMutableDictionary *smallIcons;
@property(nonatomic, strong) NSMutableDictionary *localizedTitles;
@property(nonatomic, strong) NSMutableDictionary *localizedGroups;
@property(nonatomic, strong) NSMutableDictionary *localizedDescriptions;

// Concurrency
@property(nonatomic, strong) dispatch_queue_t queue;

@end

@implementation LAListenerMetadataCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _smallIcons = [[NSMutableDictionary alloc] init];
        _localizedTitles = [[NSMutableDictionary alloc] init];
        _localizedGroups = [[NSMutableDictionary alloc] init];
        _localizedDescriptions = [[NSMutableDictionary alloc] init];
        _queue =
            dispatch_queue_create("libactivator.listener-metadata-cache", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    }
    return self;
}

- (void)removeAllObjects {
    dispatch_sync(self.queue, ^{
        [self.smallIcons removeAllObjects];
        [self.localizedTitles removeAllObjects];
        [self.localizedGroups removeAllObjects];
        [self.localizedDescriptions removeAllObjects];
    });
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

    __block id cachedObject = nil;
    dispatch_sync(self.queue, ^{
        cachedObject = cache[listenerName];
    });
    if (cachedObject) {
        return cachedObject == NSNull.null ? nil : cachedObject;
    }

    id resolvedObject = resolver ? resolver() : nil;
    dispatch_sync(self.queue, ^{
        cache[listenerName] = resolvedObject ?: NSNull.null;
    });
    return resolvedObject;
}

@end
