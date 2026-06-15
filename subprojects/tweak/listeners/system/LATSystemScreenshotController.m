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

@interface UIApplication (ScreenshotController)
- (void)_takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshotAndEdit:(BOOL)edit;
- (void)takeScreenshot;
@end

@implementation LATSystemScreenshotController

- (BOOL)editScreenshotForListenerName:(NSString *)listenerName {
    UIApplication *application = UIApplication.sharedApplication;
    if ([application respondsToSelector:@selector(_takeScreenshotAndEdit:)]) {
        [application _takeScreenshotAndEdit:YES];
    } else if ([application respondsToSelector:@selector(takeScreenshotAndEdit:)]) {
        [application takeScreenshotAndEdit:YES];
    } else if ([application respondsToSelector:@selector(takeScreenshot)]) {
        [application takeScreenshot];
    } else {
        HBLogError(@"SpringBoard cannot edit screenshot for system action %@", listenerName ?: @"");
    }
    return YES;
}

@end
