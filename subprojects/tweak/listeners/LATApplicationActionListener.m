//
//  LATApplicationActionListener.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATApplicationActionListener.h"

#import "LATApplicationDescriptor.h"
#import "LATApplicationLauncher.h"
#import "LATBuiltInRegistry.h"
#import "LATLockScreenCameraLauncher.h"
#import "LATRuntimeStateSource.h"

#import <HBLog.h>

@interface LATApplicationActionListener ()

// Dependencies
@property(nonatomic, strong) LATApplicationLauncher *launcher;
@property(nonatomic, strong) LATLockScreenCameraLauncher *lockScreenCameraLauncher;
@property(nonatomic, weak, nullable) LATBuiltInRegistry *registry;

// Descriptor cache
@property(nonatomic, strong) dispatch_queue_t descriptorQueue;
@property(nonatomic, copy) NSDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier;

@end

@implementation LATApplicationActionListener

- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher registry:(LATBuiltInRegistry *)registry {
    self = [super init];
    if (self) {
        _launcher = launcher;
        _registry = registry;
        _lockScreenCameraLauncher = [[LATLockScreenCameraLauncher alloc] initWithRegistry:_registry];
        _descriptorQueue = dispatch_queue_create("libactivator.application-action-listener.descriptors",
                                                 DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _descriptorsByIdentifier = @{};
    }
    return self;
}

- (void)setApplicationDescriptors:(NSDictionary<NSString *, LATApplicationDescriptor *> *)descriptorsByIdentifier {
    NSDictionary<NSString *, LATApplicationDescriptor *> *snapshot = [descriptorsByIdentifier copy] ?: @{};
    dispatch_sync(self.descriptorQueue, ^{
        self.descriptorsByIdentifier = snapshot;
    });
}

- (LATApplicationDescriptor *)applicationDescriptorForIdentifier:(NSString *)identifier {
    if (identifier.length == 0) {
        return nil;
    }

    __block LATApplicationDescriptor *descriptor = nil;
    dispatch_sync(self.descriptorQueue, ^{
        descriptor = self.descriptorsByIdentifier[identifier];
    });
    return descriptor;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    LATApplicationDescriptor *descriptor = [self applicationDescriptorForIdentifier:listenerName];
    if (!descriptor) {
        HBLogWarn(@"Application action %@ has no registered descriptor", listenerName ?: @"");
        return;
    }

    event.handled = YES;
    if ([self shouldOpenLockScreenCameraForDescriptor:descriptor
                                         listenerName:listenerName
                                                event:event
                                            activator:activator]) {
        if ([self.lockScreenCameraLauncher enqueueOpenLockScreenCamera]) {
            return;
        }

        HBLogWarn(@"Falling back to normal camera application launch");
    }

    [self.launcher enqueueLaunchApplicationWithIdentifier:descriptor.identifier];
}

- (BOOL)shouldOpenLockScreenCameraForDescriptor:(LATApplicationDescriptor *)descriptor
                                   listenerName:(NSString *)listenerName
                                          event:(LAEvent *)event
                                      activator:(LAActivator *)activator {
    if (![listenerName isEqualToString:@"com.apple.camera"] &&
        ![descriptor.identifier isEqualToString:@"com.apple.camera"]) {
        return NO;
    }

    NSString *eventMode = event.mode ?: activator.currentEventMode;
    if ([eventMode isEqualToString:LAEventModeLockScreen]) {
        return YES;
    }

    return self.registry.runtimeStateSource.isUILocked;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    return [self applicationDescriptorForIdentifier:listenerName].displayName;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    return [self applicationDescriptorForIdentifier:listenerName]
               ? [activator localizedStringForKey:@"LISTENER_DESCRIPTION_application" value:@"Activate application"]
               : nil;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    NSString *group = [[self applicationDescriptorForIdentifier:listenerName] applicationGroup];
    if (group.length == 0) {
        return nil;
    }
    return [activator localizedStringForKey:[@"LISTENER_GROUP_TITLE_" stringByAppendingString:group] value:group];
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    if ([key isEqualToString:@"title"]) {
        return [self activator:activator requiresLocalizedTitleForListenerName:listenerName];
    }
    if ([key isEqualToString:@"description"]) {
        return [self activator:activator requiresLocalizedDescriptionForListenerName:listenerName];
    }
    if ([key isEqualToString:@"group"]) {
        return [self activator:activator requiresLocalizedGroupForListenerName:listenerName];
    }
    return nil;
}

@end
