//
//  LATDynamicApplicationListenerProvider.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATDynamicApplicationListenerProvider.h"

#import "LAActivator+Private.h"
#import "LATApplicationActionListener.h"
#import "LATApplicationCatalog.h"
#import "LATApplicationDescriptor.h"

#import <HBLog.h>

@interface LATDynamicApplicationListenerProvider ()
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) LATApplicationCatalog *catalog;
@property(nonatomic, strong) LATApplicationActionListener *listener;
@property(nonatomic, strong) NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier;
@property(nonatomic, strong) NSMutableSet<NSString *> *registeredListenerNames;
@end

@implementation LATDynamicApplicationListenerProvider

- (instancetype)initWithActivator:(LAActivator *)activator
                          catalog:(LATApplicationCatalog *)catalog
                         listener:(LATApplicationActionListener *)listener {
    self = [super init];
    if (self) {
        _activator = activator;
        _catalog = catalog;
        _listener = listener;
        _descriptorsByIdentifier = [[NSMutableDictionary alloc] init];
        _registeredListenerNames = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self.catalog removeObserver:self];
}

- (void)start {
    [self.catalog addObserver:self];
    [self refreshApplications];
}

- (void)refreshApplications {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshApplications];
        });
        return;
    }

    NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier =
        [[NSMutableDictionary alloc] init];
    for (LATApplicationDescriptor *descriptor in [self.catalog visibleApplicationDescriptors]) {
        if (descriptor.identifier.length > 0) {
            descriptorsByIdentifier[descriptor.identifier] = descriptor;
        }
    }

    self.descriptorsByIdentifier = descriptorsByIdentifier;
    [self.listener setApplicationDescriptors:self.descriptorsByIdentifier];
    [self.registeredListenerNames removeAllObjects];
    for (NSString *identifier in self.descriptorsByIdentifier) {
        [self.activator registerListener:self.listener forName:identifier ignoreHasSeen:YES];
        [self.registeredListenerNames addObject:identifier];
    }
}

+ (NSArray *)visibleApplicationDescriptors {
    return [[[LATApplicationCatalog alloc] init] visibleApplicationDescriptors];
}

- (void)applicationsDidInstall:(id)applicationIdentifiers {
    HBLogDebug(@"Applications did install: %@", applicationIdentifiers);
    [self updateInstalledApplicationsWithIdentifiers:[self normalizedApplicationIdentifiers:applicationIdentifiers]];
}

- (void)applicationsDidUninstall:(id)applicationIdentifiers {
    HBLogDebug(@"Applications did uninstall: %@", applicationIdentifiers);
    [self removeApplicationsWithIdentifiers:[self normalizedApplicationIdentifiers:applicationIdentifiers]];
}

- (void)updateInstalledApplicationsWithIdentifiers:(NSArray<NSString *> *)applicationIdentifiers {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateInstalledApplicationsWithIdentifiers:applicationIdentifiers];
        });
        return;
    }

    for (NSString *identifier in applicationIdentifiers) {
        LATApplicationDescriptor *descriptor = [self.catalog applicationDescriptorForIdentifier:identifier];
        if (descriptor) {
            [self registerDescriptor:descriptor];
        } else {
            [self unregisterApplicationWithIdentifier:identifier];
        }
    }
}

- (void)removeApplicationsWithIdentifiers:(NSArray<NSString *> *)applicationIdentifiers {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeApplicationsWithIdentifiers:applicationIdentifiers];
        });
        return;
    }

    for (NSString *identifier in applicationIdentifiers) {
        [self unregisterApplicationWithIdentifier:identifier];
    }
}

- (void)registerDescriptor:(LATApplicationDescriptor *)descriptor {
    if (descriptor.identifier.length == 0) {
        return;
    }

    self.descriptorsByIdentifier[descriptor.identifier] = descriptor;
    [self.listener setApplicationDescriptors:self.descriptorsByIdentifier];
    [self.activator registerListener:self.listener forName:descriptor.identifier ignoreHasSeen:YES];
    [self.registeredListenerNames addObject:descriptor.identifier];
}

- (void)unregisterApplicationWithIdentifier:(NSString *)identifier {
    if (identifier.length == 0 || ![self.registeredListenerNames containsObject:identifier]) {
        return;
    }

    [self.descriptorsByIdentifier removeObjectForKey:identifier];
    [self.listener setApplicationDescriptors:self.descriptorsByIdentifier];
    [self.activator unregisterListenerWithName:identifier];
    [self.registeredListenerNames removeObject:identifier];
}

- (NSArray<NSString *> *)normalizedApplicationIdentifiers:(id)value {
    if ([value isKindOfClass:NSString.class]) {
        return @[ value ];
    }
    if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class]) {
        NSMutableArray<NSString *> *identifiers = [[NSMutableArray alloc] init];
        for (id object in value) {
            if ([object isKindOfClass:NSString.class]) {
                [identifiers addObject:object];
            }
        }
        return [identifiers copy];
    }
    return @[];
}

@end
