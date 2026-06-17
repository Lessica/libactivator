//
//  LATSystemScreenshotController.m
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemScreenshotController.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface SBScreenshotManager : NSObject
- (BOOL)writingScreenshot;
- (BOOL)_isWritingSnapshot;
@end

@interface UIApplication (ScreenshotController)
- (SBScreenshotManager *)screenshotManager;
- (void)_takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshot;
@end

@implementation LATSystemScreenshotController

- (BOOL)takeScreenshotForListenerName:(NSString *)listenerName {
    UIApplication *application = UIApplication.sharedApplication;
    if ([application respondsToSelector:@selector(screenshotManager)]) {
        SBScreenshotManager *manager = [application screenshotManager];
        if ([manager respondsToSelector:@selector(writingScreenshot)] && [manager writingScreenshot]) {
            return NO;
        }
        if ([manager respondsToSelector:@selector(_isWritingSnapshot)] && [manager _isWritingSnapshot]) {
            return NO;
        }
    }

    if ([application respondsToSelector:@selector(takeScreenshot)]) {
        [application takeScreenshot];
        return YES;
    }

    HBLogError(@"SpringBoard cannot take screenshot for system action %@", listenerName ?: @"");
    return NO;
}

- (BOOL)editScreenshotForListenerName:(NSString *)listenerName {
    UIApplication *application = UIApplication.sharedApplication;
    if ([application respondsToSelector:@selector(_takeScreenshotAndEdit:)]) {
        [application _takeScreenshotAndEdit:YES];
        return YES;
    } else if ([application respondsToSelector:@selector(takeScreenshotAndEdit:)]) {
        [application takeScreenshotAndEdit:YES];
        return YES;
    }
    return [self takeScreenshotForListenerName:listenerName];
}

@end
