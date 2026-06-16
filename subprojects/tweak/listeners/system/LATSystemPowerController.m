//
//  LATSystemPowerController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemPowerController.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <roothide.h>
#import <spawn.h>
#import <string.h>

extern char **environ;

static const NSUInteger LATSBSRelaunchActionOptionsRestartRenderServer = (1 << 0);

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(NSUInteger)options targetURL:(nullable NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(nullable void (^)(NSError *error))result;
@end

@interface SBRestartManager : NSObject
- (void)shutdownForReason:(nullable id)reason;
- (void)rebootForReason:(nullable id)reason;
@end

@interface SpringBoard : UIApplication
- (SBRestartManager *)restartManager;
@end

@interface UIApplication (DoesNotExist)
- (void)safeModeFromActivator;
@end

@interface LATSystemPowerController ()
- (BOOL)sendRelaunchActionForListenerName:(NSString *)listenerName
                                  options:(NSUInteger)options
                               actionName:(NSString *)actionName;
@end

static NSString *LATUserRebootHelperPath(void) { return jbroot(@"/usr/libexec/activator/user-reboot"); }

@implementation LATSystemPowerController

- (BOOL)respringForListenerName:(NSString *)listenerName {
    return [self sendRelaunchActionForListenerName:listenerName options:0 actionName:@"Respring"];
}

- (BOOL)hardRespringForListenerName:(NSString *)listenerName {
    return [self sendRelaunchActionForListenerName:listenerName
                                           options:LATSBSRelaunchActionOptionsRestartRenderServer
                                        actionName:@"Hard respring"];
}

- (BOOL)softRebootForListenerName:(NSString *)listenerName {
    NSString *helperPath = LATUserRebootHelperPath();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        const char *fileSystemPath = helperPath.fileSystemRepresentation;
        if (fileSystemPath == NULL) {
            HBLogError(@"Unable to resolve user reboot helper path for system action %@", listenerName ?: @"");
            return;
        }

        pid_t pid = 0;
        char *const argv[] = {(char *)fileSystemPath, NULL};
        int status = posix_spawn(&pid, fileSystemPath, NULL, NULL, argv, environ);
        if (status != 0) {
            HBLogError(@"Unable to spawn user reboot helper for system action %@: %s", listenerName ?: @"",
                       strerror(status));
        }
    });
    return YES;
}

- (BOOL)sendRelaunchActionForListenerName:(NSString *)listenerName
                                  options:(NSUInteger)options
                               actionName:(NSString *)actionName {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Class actionClass = NSClassFromString(@"SBSRelaunchAction");
        Class serviceClass = NSClassFromString(@"FBSSystemService");
        if (![actionClass respondsToSelector:@selector(actionWithReason:options:targetURL:)] ||
            ![serviceClass respondsToSelector:@selector(sharedService)]) {
            HBLogError(@"Unable to perform %@ for system action %@ because FrontBoard relaunch SPI is unavailable",
                       actionName ?: @"relaunch", listenerName ?: @"");
            return;
        }

        SBSRelaunchAction *action =
            [(id)actionClass actionWithReason:(listenerName ?: @"libactivator") options:options targetURL:nil];
        FBSSystemService *service = [(id)serviceClass sharedService];
        if (![service respondsToSelector:@selector(sendActions:withResult:)]) {
            HBLogError(@"FBSSystemService does not support sendActions:withResult:");
            return;
        }

        [service sendActions:[NSSet setWithObject:action]
                  withResult:^(NSError *error) {
                      if (error) {
                          HBLogError(@"%@ action %@ failed: %@", actionName ?: @"Relaunch", listenerName ?: @"", error);
                      }
                  }];
    });
    return YES;
}

- (BOOL)safeModeForListenerName:(NSString *)listenerName {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        HBLogWarn(@"Triggering Safe Mode for system action %@ via safeModeFromActivator exception",
                  listenerName ?: @"");
        [UIApplication.sharedApplication safeModeFromActivator];
    });
    return YES;
}

- (BOOL)powerDownForListenerName:(NSString *)listenerName {
    SBRestartManager *restartManager = [self restartManagerForListenerName:listenerName];
    if (!restartManager) {
        return YES;
    }
    if (![restartManager respondsToSelector:@selector(shutdownForReason:)]) {
        HBLogError(@"SBRestartManager does not support shutdownForReason: for system action %@", listenerName ?: @"");
        return YES;
    }
    [restartManager shutdownForReason:nil];
    return YES;
}

- (BOOL)rebootForListenerName:(NSString *)listenerName {
    SBRestartManager *restartManager = [self restartManagerForListenerName:listenerName];
    if (!restartManager) {
        return YES;
    }
    if (![restartManager respondsToSelector:@selector(rebootForReason:)]) {
        HBLogError(@"SBRestartManager does not support rebootForReason: for system action %@", listenerName ?: @"");
        return YES;
    }
    [restartManager rebootForReason:nil];
    return YES;
}

- (nullable SBRestartManager *)restartManagerForListenerName:(NSString *)listenerName {
    UIApplication *application = UIApplication.sharedApplication;
    if (![application respondsToSelector:@selector(restartManager)]) {
        HBLogError(@"SpringBoard does not support restartManager for system action %@", listenerName ?: @"");
        return nil;
    }
    return [(SpringBoard *)application restartManager];
}

@end
