//
//  LASettingsViewController.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Settings View Controllers represent view controllers that can be displayed the Activator app, Activator's settings
// pane, and possibly in other Activator-integrated apps

#ifndef LA_SETTINGS_CONTROLLER
#define LA_SETTINGS_CONTROLLER(superclass) : superclass
#endif

@interface LASettingsViewController
LA_SETTINGS_CONTROLLER(UIViewController)
+ (instancetype)controller;
- (instancetype)init;
@end

@interface LARootSettingsController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
@end

@interface LAModeSettingsController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
- (instancetype)initWithMode:(NSString *)mode;
@end

@interface LAEventSettingsController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
- (instancetype)initWithModes:(NSArray *)modes eventName:(NSString *)eventName;
@end

@interface LAListenerSettingsViewController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
@property(nonatomic, copy) NSString *listenerName;
@end

@interface LAEventConfigurationViewController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
- (instancetype)initWithEventName:(NSString *)eventName;
@property(nonatomic, readonly, copy) NSString *eventName;
@property(nonatomic, assign) BOOL showsSaveButton;
- (BOOL)performSave;
@end

@interface LAListenerConfigurationViewController
LA_SETTINGS_CONTROLLER(LASettingsViewController)
- (instancetype)initWithListenerName:(NSString *)listenerName;
@property(nonatomic, readonly, copy) NSString *listenerName;
@property(nonatomic, assign) BOOL showsSaveButton;
- (BOOL)performSave;
@end

NS_ASSUME_NONNULL_END
