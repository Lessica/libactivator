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

#import <HBLog.h>

@interface LATApplicationActionListener ()
@property(nonatomic, strong) LATApplicationLauncher *launcher;
@property(nonatomic, strong) dispatch_queue_t descriptorQueue;
@property(nonatomic, copy) NSDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier;
@end

@implementation LATApplicationActionListener

- (instancetype)initWithLauncher:(LATApplicationLauncher *)launcher {
    self = [super init];
    if (self) {
        _launcher = launcher;
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
    [self.launcher enqueueLaunchApplicationWithIdentifier:descriptor.identifier];
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
