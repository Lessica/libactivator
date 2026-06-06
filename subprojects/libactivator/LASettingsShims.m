//
//  LASettingsShims.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/LASettingsViewController.h>

@interface LAModeSettingsController ()
@property(nonatomic, copy) NSString *mode;
@end

@interface LAEventSettingsController ()
@property(nonatomic, copy) NSArray *modes;
@property(nonatomic, copy) NSString *eventName;
@end

@interface LAEventConfigurationViewController () {
    NSString *_eventName;
}
@end

@interface LAListenerConfigurationViewController () {
    NSString *_listenerName;
}
@end

@implementation LASettingsViewController

+ (instancetype)controller {
    return [[self alloc] init];
}

- (instancetype)init {
    return [super init];
}

@end

@implementation LARootSettingsController
@end

@implementation LAModeSettingsController

- (instancetype)initWithMode:(NSString *)mode {
    self = [super init];
    if (self) {
        _mode = [mode copy];
    }
    return self;
}

@end

@implementation LAEventSettingsController

- (instancetype)initWithModes:(NSArray *)modes eventName:(NSString *)eventName {
    self = [super init];
    if (self) {
        _modes = [modes copy];
        _eventName = [eventName copy];
    }
    return self;
}

@end

@implementation LAListenerSettingsViewController
@end

@implementation LAEventConfigurationViewController

@synthesize eventName = _eventName;

- (instancetype)initWithEventName:(NSString *)eventName {
    self = [super init];
    if (self) {
        _eventName = [eventName copy];
    }
    return self;
}

- (BOOL)performSave {
    return YES;
}

@end

@implementation LAListenerConfigurationViewController

@synthesize listenerName = _listenerName;

- (instancetype)initWithListenerName:(NSString *)listenerName {
    self = [super init];
    if (self) {
        _listenerName = [listenerName copy];
    }
    return self;
}

- (BOOL)performSave {
    return YES;
}

@end
