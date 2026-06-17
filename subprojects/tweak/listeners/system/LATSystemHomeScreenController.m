//
//  LATSystemHomeScreenController.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemHomeScreenController.h"

#import <HBLog.h>

@interface SBSServiceFacilityClient : NSObject
+ (id)checkOutClientWithClass:(Class)clientClass;
@end

@interface SBSSystemServiceClient : NSObject
- (void)resetToHomeScreenAnimated:(BOOL)animated;
- (void)resetToHomeScreenAnimated:(BOOL)animated useSafeTransitions:(BOOL)useSafeTransitions;
@end

@implementation LATSystemHomeScreenController

- (BOOL)resetToFirstSpringBoardPageForListenerName:(NSString *)listenerName {
    Class facilityClass = NSClassFromString(@"SBSServiceFacilityClient");
    Class serviceClass = NSClassFromString(@"SBSSystemServiceClient");
    if (![facilityClass respondsToSelector:@selector(checkOutClientWithClass:)] || !serviceClass) {
        HBLogError(@"Unable to reset to first SpringBoard page for system action %@ because SBS system service is "
                   @"unavailable",
                   listenerName ?: @"");
        return NO;
    }

    SBSSystemServiceClient *service = [facilityClass checkOutClientWithClass:serviceClass];
    BOOL supportsSafeReset = [service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)];
    BOOL supportsReset = [service respondsToSelector:@selector(resetToHomeScreenAnimated:)];
    if (!supportsSafeReset && !supportsReset) {
        HBLogError(@"SBSSystemServiceClient does not support resetToHomeScreenAnimated:");
        return NO;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (supportsSafeReset) {
            [service resetToHomeScreenAnimated:YES useSafeTransitions:YES];
            return;
        }
        [service resetToHomeScreenAnimated:YES];
    });
    return YES;
}

@end
