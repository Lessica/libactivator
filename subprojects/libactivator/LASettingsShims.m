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

+ (id)controller {
    return [[self alloc] init];
}

- (id)init {
    return [super init];
}

@end

@implementation LARootSettingsController
@end

@implementation LAModeSettingsController

- (id)initWithMode:(NSString *)mode {
    self = [super init];
    if (self) {
        _mode = [mode copy];
    }
    return self;
}

@end

@implementation LAEventSettingsController

- (id)initWithModes:(NSArray *)modes eventName:(NSString *)eventName {
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

- (id)initWithEventName:(NSString *)eventName {
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

- (id)initWithListenerName:(NSString *)listenerName {
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
