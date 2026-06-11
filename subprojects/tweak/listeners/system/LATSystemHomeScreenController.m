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
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Class facilityClass = NSClassFromString(@"SBSServiceFacilityClient");
        Class serviceClass = NSClassFromString(@"SBSSystemServiceClient");
        if (![facilityClass respondsToSelector:@selector(checkOutClientWithClass:)] || !serviceClass) {
            HBLogError(@"Unable to reset to first SpringBoard page for system action %@ because SBS system service is "
                       @"unavailable",
                       listenerName ?: @"");
            return;
        }

        SBSSystemServiceClient *service = [facilityClass checkOutClientWithClass:serviceClass];
        if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)]) {
            [service resetToHomeScreenAnimated:YES useSafeTransitions:YES];
        } else if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:)]) {
            [service resetToHomeScreenAnimated:YES];
        } else {
            HBLogError(@"SBSSystemServiceClient does not support resetToHomeScreenAnimated:");
        }
    });
    return YES;
}

@end
