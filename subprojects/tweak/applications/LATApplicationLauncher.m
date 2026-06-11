//
//  LATApplicationLauncher.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATApplicationLauncher.h"

#import <HBLog.h>

FOUNDATION_EXTERN NSString *SBSApplicationLaunchOptionUnlockDeviceKey;
extern int SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFStringRef identifier, CFDictionaryRef launchOptions,
                                                              BOOL suspended);
extern CFStringRef SBSApplicationLaunchingErrorString(int errorCode);

@interface LATApplicationLauncher ()
@property(nonatomic, strong) dispatch_queue_t queue;
@end

@implementation LATApplicationLauncher

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_USER_INITIATED, 0);
        _queue = dispatch_queue_create("libactivator.application-launch", attr);
        dispatch_queue_set_specific(_queue, (__bridge const void *)(self), (__bridge void *)self, NULL);
    }
    return self;
}

#pragma mark - Public API

- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier {
    if (identifier.length == 0) {
        HBLogError(@"Unable to launch application because identifier is empty");
        return NO;
    }

    if (dispatch_get_specific((__bridge const void *)(self))) {
        return [self launchApplicationOnQueueWithIdentifier:identifier];
    }

    __block BOOL launched = NO;
    dispatch_sync(self.queue, ^{
        launched = [self launchApplicationOnQueueWithIdentifier:identifier];
    });
    return launched;
}

#pragma mark - Internal

- (BOOL)launchApplicationOnQueueWithIdentifier:(NSString *)identifier {
    NSDictionary *launchOptions = @{SBSApplicationLaunchOptionUnlockDeviceKey : @YES};
    int result = SBSLaunchApplicationWithIdentifierAndLaunchOptions((__bridge CFStringRef)identifier,
                                                                    (__bridge CFDictionaryRef)launchOptions, NO);
    if (result == 0) {
        return YES;
    }

    CFStringRef errorString = SBSApplicationLaunchingErrorString(result);
    NSString *errorDescription = errorString ? (__bridge NSString *)errorString : nil;
    HBLogError(@"SBSLaunchApplicationWithIdentifierAndLaunchOptions failed for %@: %d %@", identifier ?: @"", result,
               errorDescription ?: @"");
    return NO;
}

@end
