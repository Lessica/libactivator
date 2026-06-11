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

static CFStringRef const LATLaunchServicesApplicationsChangedNotification =
    CFSTR("com.apple.LaunchServices.ApplicationsChanged");
static NSTimeInterval const LATApplicationRefreshDebounceDelay = 1.0;

@interface LATDynamicApplicationListenerProvider ()
@property(nonatomic, weak) LAActivator *activator;
@property(nonatomic, strong) LATApplicationCatalog *catalog;
@property(nonatomic, strong) LATApplicationActionListener *listener;
@property(nonatomic, strong) NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier;
@property(nonatomic, strong) NSMutableSet<NSString *> *registeredListenerNames;
@property(nonatomic, assign) NSUInteger refreshGeneration;
- (void)launchServicesApplicationsDidChange;
- (void)scheduleRefreshApplicationsAfterDelay:(NSTimeInterval)delay;
- (void)applyApplicationDescriptorsByIdentifier:
    (NSDictionary<NSString *, LATApplicationDescriptor *> *)descriptorsByIdentifier;
@end

static void LATLaunchServicesApplicationsChangedCallback(__unused CFNotificationCenterRef center, void *observer,
                                                         __unused CFStringRef name, __unused const void *object,
                                                         __unused CFDictionaryRef userInfo) {
    LATDynamicApplicationListenerProvider *provider = (__bridge LATDynamicApplicationListenerProvider *)observer;
    [provider launchServicesApplicationsDidChange];
}

@implementation LATDynamicApplicationListenerProvider

#pragma mark - Lifecycle

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
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self,
                                       LATLaunchServicesApplicationsChangedNotification, NULL);
}

#pragma mark - Public API

- (void)start {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self,
                                    LATLaunchServicesApplicationsChangedCallback,
                                    LATLaunchServicesApplicationsChangedNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    [self refreshApplications];
}

- (void)refreshApplications {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshApplications];
        });
        return;
    }

    NSUInteger refreshGeneration = ++self.refreshGeneration;
    LATApplicationCatalog *catalog = self.catalog;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier =
                [[NSMutableDictionary alloc] init];
            for (LATApplicationDescriptor *descriptor in [catalog visibleApplicationDescriptors]) {
                if (descriptor.identifier.length > 0) {
                    descriptorsByIdentifier[descriptor.identifier] = descriptor;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (refreshGeneration != self.refreshGeneration) {
                    return;
                }
                [self applyApplicationDescriptorsByIdentifier:descriptorsByIdentifier];
            });
        }
    });
}

- (void)scheduleRefreshApplicationsAfterDelay:(NSTimeInterval)delay {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scheduleRefreshApplicationsAfterDelay:delay];
        });
        return;
    }

    self.refreshGeneration++;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshApplications) object:nil];
    [self performSelector:@selector(refreshApplications) withObject:nil afterDelay:delay];
}

- (void)applyApplicationDescriptorsByIdentifier:
    (NSDictionary<NSString *, LATApplicationDescriptor *> *)snapshotDescriptorsByIdentifier {
    NSMutableDictionary<NSString *, LATApplicationDescriptor *> *descriptorsByIdentifier =
        [snapshotDescriptorsByIdentifier mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSSet<NSString *> *currentListenerNames = [NSSet setWithArray:descriptorsByIdentifier.allKeys];

    self.descriptorsByIdentifier = descriptorsByIdentifier;
    [self.listener setApplicationDescriptors:self.descriptorsByIdentifier];

    NSMutableSet<NSString *> *removedListenerNames = [self.registeredListenerNames mutableCopy];
    [removedListenerNames minusSet:currentListenerNames];
    for (NSString *identifier in removedListenerNames) {
        [self.activator unregisterListenerWithName:identifier];
        [self.registeredListenerNames removeObject:identifier];
    }

    NSMutableSet<NSString *> *addedListenerNames = [currentListenerNames mutableCopy];
    [addedListenerNames minusSet:self.registeredListenerNames];
    for (NSString *identifier in addedListenerNames) {
        [self.activator registerListener:self.listener forName:identifier ignoreHasSeen:YES];
        [self.registeredListenerNames addObject:identifier];
    }
}

+ (NSArray<LATApplicationDescriptor *> *)visibleApplicationDescriptors {
    return [[[LATApplicationCatalog alloc] init] visibleApplicationDescriptors];
}

#pragma mark - Application Catalog Notifications

- (void)launchServicesApplicationsDidChange {
    HBLogDebug(@"LaunchServices applications changed");
    [self scheduleRefreshApplicationsAfterDelay:LATApplicationRefreshDebounceDelay];
}

@end
