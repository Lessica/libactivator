#import <Activator/Activator.h>

LAActivator *LASharedActivator = nil;

@implementation LAActivator

+ (LAActivator *)sharedInstance
{
    @synchronized (self) {
        if (!LASharedActivator) {
            LASharedActivator = [[self alloc] initPrivate];
        }
    }
    return LASharedActivator;
}

- (instancetype)init
{
    return [[self class] sharedInstance];
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _currentProfileName = @"Default";
    }
    return self;
}

- (LAActivatorVersion)version
{
    return LAActivatorVersion_2_0;
}

- (BOOL)isRunningInsideSpringBoard
{
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

- (BOOL)isDangerousToSendEvents
{
    return NO;
}

- (id<LAListener>)listenerForEvent:(LAEvent *)event
{
    return nil;
}

- (void)sendEventToListener:(LAEvent *)event
{
}

- (void)sendEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
}

- (void)sendEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames
{
}

- (void)sendAbortToListener:(LAEvent *)event
{
}

- (void)sendAbortEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
}

- (void)sendAbortEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames
{
}

- (void)sendPreviewEventToListenerWithName:(NSString *)listenerName
{
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event
{
}

- (id<LAListener>)listenerForName:(NSString *)name
{
    return nil;
}

- (BOOL)hasListenerWithName:(NSString *)name
{
    return NO;
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name
{
}

- (void)unregisterListenerWithName:(NSString *)name
{
}

- (BOOL)hasSeenListenerWithName:(NSString *)name
{
    return NO;
}

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName
{
}

- (void)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames
{
}

- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event
{
}

- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event
{
}

- (void)unassignEvent:(LAEvent *)event
{
}

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event
{
    return nil;
}

- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event
{
    return @[];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName
{
    return @[];
}

- (NSArray *)availableEventNames
{
    return @[];
}

- (BOOL)hasEventWithName:(NSString *)name
{
    return NO;
}

- (BOOL)eventWithNameIsHidden:(NSString *)name
{
    return NO;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)name
{
    return YES;
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name
{
    return @[];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
    return NO;
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName
{
    return NO;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName
{
    return NO;
}

- (void)removeEventWithName:(NSString *)eventName
{
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName
{
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName
{
}

- (BOOL)eventWithNameSupportsConfiguration:(NSString *)eventName
{
    return NO;
}

- (LAEventConfigurationViewController *)configurationViewControllerForEventWithName:(NSString *)eventName
{
    return nil;
}

- (NSArray *)availableListenerNames
{
    return @[];
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name
{
    return nil;
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name
{
    return YES;
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name
{
    return @[];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(NSString *)eventMode
{
    return NO;
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName
{
    return NO;
}

- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName
{
    return NO;
}

- (NSArray *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName
{
    return @[];
}

- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames
{
    return YES;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName
{
    return nil;
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName
{
    return nil;
}

- (UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle
{
    return nil;
}

- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName
{
    return NO;
}

- (void)requestRemovalForListenerWithName:(NSString *)listenerName
{
}

- (BOOL)listenerWithNameSupportsConfiguration:(NSString *)listenerName
{
    return NO;
}

- (LAListenerConfigurationViewController *)configurationViewControllerForListenerWithName:(NSString *)listenerName
{
    return nil;
}

- (NSArray *)availableEventModes
{
    return @[LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen];
}

- (NSString *)currentEventMode
{
    return self.runningInsideSpringBoard ? LAEventModeSpringBoard : LAEventModeApplication;
}

- (NSString *)currentEventModeUnderneathLockScreen
{
    return LAEventModeApplication;
}

- (BOOL)supportsUnlockingDeviceToSendEvents
{
    return NO;
}

- (NSString *)displayIdentifierForCurrentApplication
{
    return [[NSBundle mainBundle] bundleIdentifier];
}

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier
{
    return NO;
}

- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted
{
}

- (NSArray *)availableProfileNames
{
    return self.currentProfileName ? @[self.currentProfileName] : @[];
}

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value
{
    if (value.length > 0) {
        return value;
    }
    if (key.length > 0) {
        return key;
    }
    return @"";
}

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode
{
    return [self localizedStringForKey:eventMode value:eventMode];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName
{
    return [self localizedStringForKey:eventName value:eventName];
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName
{
    return [self localizedStringForKey:listenerName value:listenerName];
}

- (NSString *)localizedTitleForListenerNames:(NSArray *)listenerNames
{
    NSMutableArray *localizedNames = [NSMutableArray arrayWithCapacity:listenerNames.count];
    for (NSString *listenerName in listenerNames) {
        [localizedNames addObject:[self localizedTitleForListenerName:listenerName]];
    }
    return [localizedNames componentsJoinedByString:@", "];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
    return @"";
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName
{
    return @"";
}

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode
{
    return [self localizedTitleForEventMode:eventMode];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
    return [self localizedTitleForEventName:eventName];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
{
    return [self localizedTitleForListenerName:listenerName];
}

@end
