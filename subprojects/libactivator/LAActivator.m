#import <Activator/Activator.h>
#import <dispatch/dispatch.h>

#pragma mark - Class Extension

@interface LAActivator ()
@property(nonatomic, strong) NSMutableDictionary *eventDataSources;
@property(nonatomic, strong) NSMutableDictionary *listeners;
@property(nonatomic, strong) NSMutableDictionary *assignments;
@property(nonatomic, strong) NSMutableSet *blacklistedDisplayIdentifiers;
@property(nonatomic, strong) NSMutableSet *profileNames;
@property(nonatomic, strong) dispatch_queue_t stateQueue;
@end

@implementation LAActivator

@synthesize currentProfileName = _currentProfileName;

#pragma mark - Lifecycle

LAActivator *LASharedActivator;

+ (void)load {
    [self sharedInstance];
}

+ (LAActivator *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LASharedActivator = [[self alloc] initPrivate];
    });
    return LASharedActivator;
}

- (instancetype)init {
    return [[self class] sharedInstance];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _eventDataSources = [[NSMutableDictionary alloc] init];
        _listeners = [[NSMutableDictionary alloc] init];
        _assignments = [[NSMutableDictionary alloc] init];
        _blacklistedDisplayIdentifiers = [[NSMutableSet alloc] init];
        _profileNames = [NSMutableSet setWithObject:@"Default"];
        _stateQueue = dispatch_queue_create("libactivator.state", DISPATCH_QUEUE_SERIAL);
        _currentProfileName = @"Default";
    }
    return self;
}

#pragma mark - Utilities

+ (NSArray *)normalizedStringArray:(NSArray *)array {
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:array.count];
    for (id value in array) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![strings containsObject:value]) {
            [strings addObject:value];
        }
    }
    return [strings copy];
}

#pragma mark - Runtime State

- (LAActivatorVersion)version {
    return LAActivatorVersion_2_0;
}

- (BOOL)isRunningInsideSpringBoard {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

- (BOOL)isDangerousToSendEvents {
    return NO;
}

#pragma mark - Event Delivery

- (id<LAListener>)listenerForEvent:(LAEvent *)event {
    NSString *listenerName = [self assignedListenerNameForEvent:event];
    return [self listenerForName:listenerName];
}

- (void)sendEventToListener:(LAEvent *)event {
}

- (void)sendEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
}

- (void)sendEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
}

- (void)sendAbortToListener:(LAEvent *)event {
}

- (void)sendAbortEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
}

- (void)sendAbortEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
}

- (void)sendPreviewEventToListenerWithName:(NSString *)listenerName {
}

- (void)sendDeactivateEventToListeners:(LAEvent *)event {
}

#pragma mark - Listener Registry

- (id<LAListener>)listenerForName:(NSString *)name {
    if (name.length == 0) {
        return nil;
    }
    __block id<LAListener> listener = nil;
    dispatch_sync(self.stateQueue, ^{
        listener = self.listeners[name];
    });
    return listener;
}

- (BOOL)hasListenerWithName:(NSString *)name {
    return [self listenerForName:name] != nil;
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name {
    if (!listener || name.length == 0) {
        return;
    }
    dispatch_sync(self.stateQueue, ^{
        self.listeners[name] = listener;
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                      object:self];
}

- (void)unregisterListenerWithName:(NSString *)name {
    if (name.length == 0) {
        return;
    }
    dispatch_sync(self.stateQueue, ^{
        [self.listeners removeObjectForKey:name];
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                      object:self];
}

- (BOOL)hasSeenListenerWithName:(NSString *)name {
    return [self hasListenerWithName:name];
}

#pragma mark - Assignment Model

- (void)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName {
    if (listenerName.length > 0) {
        [self assignEvent:event toListenersWithNames:@[ listenerName ]];
    } else {
        [self unassignEvent:event];
    }
}

- (void)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames {
    if (event.name.length == 0) {
        return;
    }
    NSString *eventKey = [NSString stringWithFormat:@"%@\n%@", event.name, event.mode ?: @""];

    NSArray *normalizedNames = [LAActivator normalizedStringArray:listenerNames];
    dispatch_sync(self.stateQueue, ^{
        if (normalizedNames.count > 0) {
            self.assignments[eventKey] = @{
                @"name" : event.name,
                @"mode" : event.mode ?: @"",
                @"listeners" : normalizedNames,
            };
        } else {
            [self.assignments removeObjectForKey:eventKey];
        }
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
}

- (void)addListenerAssignment:(NSString *)listenerName toEvent:(LAEvent *)event {
    if (listenerName.length == 0) {
        return;
    }
    NSMutableArray *listenerNames = [[self assignedListenerNamesForEvent:event] mutableCopy];
    if (![listenerNames containsObject:listenerName]) {
        [listenerNames addObject:listenerName];
        [self assignEvent:event toListenersWithNames:listenerNames];
    }
}

- (void)removeListenerAssignment:(NSString *)listenerName fromEvent:(LAEvent *)event {
    if (listenerName.length == 0) {
        return;
    }
    NSMutableArray *listenerNames = [[self assignedListenerNamesForEvent:event] mutableCopy];
    [listenerNames removeObject:listenerName];
    [self assignEvent:event toListenersWithNames:listenerNames];
}

- (void)unassignEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return;
    }
    NSString *eventKey = [NSString stringWithFormat:@"%@\n%@", event.name, event.mode ?: @""];
    dispatch_sync(self.stateQueue, ^{
        [self.assignments removeObjectForKey:eventKey];
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
}

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event {
    return [[self assignedListenerNamesForEvent:event] firstObject];
}

- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event {
    if (event.name.length == 0) {
        return @[];
    }
    NSString *eventKey = [NSString stringWithFormat:@"%@\n%@", event.name, event.mode ?: @""];
    __block NSArray *listenerNames = nil;
    dispatch_sync(self.stateQueue, ^{
        listenerNames = [self.assignments[eventKey][@"listeners"] copy];
    });
    return listenerNames ?: @[];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    if (listenerName.length == 0) {
        return @[];
    }

    NSMutableArray *events = [NSMutableArray array];
    dispatch_sync(self.stateQueue, ^{
        for (NSDictionary *assignment in self.assignments.allValues) {
            if (![assignment[@"listeners"] containsObject:listenerName]) {
                continue;
            }
            NSString *mode = assignment[@"mode"];
            LAEvent *event = [LAEvent eventWithName:assignment[@"name"] mode:mode.length > 0 ? mode : nil];
            [events addObject:event];
        }
    });
    return [events copy];
}

#pragma mark - Event Registry

- (NSArray *)availableEventNames {
    __block NSArray *eventNames = nil;
    dispatch_sync(self.stateQueue, ^{
        eventNames = [self.eventDataSources.allKeys sortedArrayUsingSelector:@selector(compare:)];
    });
    return eventNames;
}

- (BOOL)hasEventWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    __block BOOL hasEvent = NO;
    dispatch_sync(self.stateQueue, ^{
        hasEvent = self.eventDataSources[name] != nil;
    });
    return hasEvent;
}

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return nil;
    }
    __block id<LAEventDataSource> dataSource = nil;
    dispatch_sync(self.stateQueue, ^{
        dataSource = self.eventDataSources[eventName];
    });
    return dataSource;
}

- (BOOL)eventWithNameIsHidden:(NSString *)name {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameIsHidden:)]) {
        return [dataSource eventWithNameIsHidden:name];
    }
    return NO;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)name {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameRequiresAssignment:)]) {
        return [dataSource eventWithNameRequiresAssignment:name];
    }
    return YES;
}

- (NSArray *)compatibleModesForEventWithName:(NSString *)name {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:name];
    if (!dataSource) {
        return @[];
    }
    if (![dataSource respondsToSelector:@selector(eventWithName:isCompatibleWithMode:)]) {
        return self.availableEventModes;
    }

    NSMutableArray *modes = [NSMutableArray array];
    for (NSString *mode in self.availableEventModes) {
        if ([dataSource eventWithName:name isCompatibleWithMode:mode]) {
            [modes addObject:mode];
        }
    }
    return [modes copy];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    if (eventName.length == 0 || eventMode.length == 0) {
        return NO;
    }
    return [[self compatibleModesForEventWithName:eventName] containsObject:eventMode];
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameSupportsUnlockingDeviceToSend:)]) {
        return [dataSource eventWithNameSupportsUnlockingDeviceToSend:eventName];
    }
    return NO;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(eventWithNameSupportsRemoval:)]) {
        return [dataSource eventWithNameSupportsRemoval:eventName];
    }
    return NO;
}

- (void)removeEventWithName:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource && [dataSource respondsToSelector:@selector(removeEventWithName:)]) {
        [dataSource removeEventWithName:eventName];
    }
    [self unregisterEventDataSourceWithEventName:eventName];
}

- (void)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName {
    if (!dataSource || eventName.length == 0) {
        return;
    }
    dispatch_sync(self.stateQueue, ^{
        self.eventDataSources[eventName] = dataSource;
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification object:self];
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if (eventName.length == 0) {
        return;
    }
    dispatch_sync(self.stateQueue, ^{
        [self.eventDataSources removeObjectForKey:eventName];
    });
    [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification object:self];
}

- (BOOL)eventWithNameSupportsConfiguration:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    return dataSource &&
           [dataSource respondsToSelector:@selector(configurationViewControllerClassNameForEventWithName:bundle:)];
}

- (LAEventConfigurationViewController *)configurationViewControllerForEventWithName:(NSString *)eventName {
    return nil;
}

#pragma mark - Listener Metadata

- (NSArray *)availableListenerNames {
    __block NSArray *listenerNames = nil;
    dispatch_sync(self.stateQueue, ^{
        listenerNames = [self.listeners.allKeys sortedArrayUsingSelector:@selector(compare:)];
    });
    return listenerNames;
}

- (id)infoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)name {
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresInfoDictionaryValueOfKey:forListenerWithName:)]) {
        return [listener activator:self requiresInfoDictionaryValueOfKey:key forListenerWithName:name];
    }
    return nil;
}

- (BOOL)listenerWithNameRequiresAssignment:(NSString *)name {
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:requiresRequiresAssignmentForListenerName:)]) {
        return [[listener activator:self requiresRequiresAssignmentForListenerName:name] boolValue];
    }
    return YES;
}

- (NSArray *)compatibleEventModesForListenerWithName:(NSString *)name {
    id<LAListener> listener = [self listenerForName:name];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresCompatibleEventModesForListenerWithName:)]) {
        return [LAActivator normalizedStringArray:[listener activator:self
                                                      requiresCompatibleEventModesForListenerWithName:name]];
    }
    return [self hasListenerWithName:name] ? self.availableEventModes : @[];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithMode:(NSString *)eventMode {
    if (listenerName.length == 0 || eventMode.length == 0) {
        return NO;
    }
    return [[self compatibleEventModesForListenerWithName:listenerName] containsObject:eventMode];
}

- (BOOL)listenerWithName:(NSString *)listenerName isCompatibleWithEventName:(NSString *)eventName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (!listener || eventName.length == 0) {
        return NO;
    }
    if ([listener respondsToSelector:@selector(activator:requiresIsCompatibleWithEventName:listenerName:)]) {
        return [[listener activator:self requiresIsCompatibleWithEventName:eventName
                                 listenerName:listenerName] boolValue];
    }
    return YES;
}

- (BOOL)listenerWithNameNeedsPoweredDisplay:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresNeedsPoweredDisplayForListenerName:)]) {
        return [listener activator:self requiresNeedsPoweredDisplayForListenerName:listenerName];
    }
    return NO;
}

- (NSArray *)exclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:
                                                     requiresExclusiveAssignmentGroupsForListenerName:)]) {
        return [LAActivator normalizedStringArray:[listener activator:self
                                                      requiresExclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    return @[];
}

- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames {
    NSArray *normalizedNames = [LAActivator normalizedStringArray:listenerNames];
    NSMutableDictionary *groupOwners = [NSMutableDictionary dictionary];
    for (NSString *listenerName in normalizedNames) {
        for (NSString *group in [self exclusiveAssignmentGroupsForListenerName:listenerName]) {
            NSString *owner = groupOwners[group];
            if (owner && ![owner isEqualToString:listenerName]) {
                return NO;
            }
            groupOwners[group] = listenerName;
        }
    }
    return YES;
}

- (UIImage *)iconForListenerName:(NSString *)listenerName {
    return nil;
}

- (UIImage *)smallIconForListenerName:(NSString *)listenerName {
    return nil;
}

- (UIImage *)imageForListenerName:(NSString *)listenerName usingTemplate:(NSBundle *)templateBundle {
    return nil;
}

- (BOOL)listenerWithNameSupportsRemoval:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresSupportsRemovalForListenerWithName:)]) {
        return [listener activator:self requiresSupportsRemovalForListenerWithName:listenerName];
    }
    return NO;
}

- (void)requestRemovalForListenerWithName:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requestsRemovalForListenerWithName:)]) {
        [listener activator:self requestsRemovalForListenerWithName:listenerName];
    }
}

- (BOOL)listenerWithNameSupportsConfiguration:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    return (listener && [listener respondsToSelector:@selector(activator:
                                                          requiresConfigurationViewControllerClassNameForListenerWithName:
                                                                                                                 bundle:)]) ||
           (listener && [listener respondsToSelector:@selector(activator:requestsConfigurationForListenerWithName:)]);
}

- (LAListenerConfigurationViewController *)configurationViewControllerForListenerWithName:(NSString *)listenerName {
    return nil;
}

#pragma mark - Event Modes

- (NSArray *)availableEventModes {
    return @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
}

- (NSString *)currentEventMode {
    return self.runningInsideSpringBoard ? LAEventModeSpringBoard : LAEventModeApplication;
}

- (NSString *)currentEventModeUnderneathLockScreen {
    return LAEventModeApplication;
}

- (BOOL)supportsUnlockingDeviceToSendEvents {
    return NO;
}

#pragma mark - Blacklist

- (NSString *)displayIdentifierForCurrentApplication {
    return [[NSBundle mainBundle] bundleIdentifier];
}

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier {
    if (displayIdentifier.length == 0) {
        return NO;
    }
    __block BOOL blacklisted = NO;
    dispatch_sync(self.stateQueue, ^{
        blacklisted = [self.blacklistedDisplayIdentifiers containsObject:displayIdentifier];
    });
    return blacklisted;
}

- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    if (displayIdentifier.length == 0) {
        return;
    }
    dispatch_sync(self.stateQueue, ^{
        if (blacklisted) {
            [self.blacklistedDisplayIdentifiers addObject:displayIdentifier];
        } else {
            [self.blacklistedDisplayIdentifiers removeObject:displayIdentifier];
        }
    });
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    __block NSArray *profileNames = nil;
    dispatch_sync(self.stateQueue, ^{
        profileNames = [self.profileNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
    });
    return profileNames;
}

- (NSString *)currentProfileName {
    __block NSString *profileName = nil;
    dispatch_sync(self.stateQueue, ^{
        profileName = _currentProfileName;
    });
    return profileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    NSString *profileName = currentProfileName.length > 0 ? [currentProfileName copy] : @"Default";
    dispatch_sync(self.stateQueue, ^{
        _currentProfileName = profileName;
        [self.profileNames addObject:profileName];
    });
}

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value {
    if (value.length > 0) {
        return value;
    }
    if (key.length > 0) {
        return key;
    }
    return @"";
}

- (NSString *)localizedTitleForEventMode:(NSString *)eventMode {
    return [self localizedStringForKey:eventMode value:eventMode];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [self localizedStringForKey:eventName value:[dataSource localizedTitleForEventName:eventName]];
    }
    return [self localizedStringForKey:eventName value:eventName];
}

- (NSString *)localizedTitleForListenerName:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedTitleForListenerName:)]) {
        return [self localizedStringForKey:listenerName
                                     value:[listener activator:self
                                               requiresLocalizedTitleForListenerName:listenerName]];
    }
    return [self localizedStringForKey:listenerName value:listenerName];
}

- (NSString *)localizedTitleForListenerNames:(NSArray *)listenerNames {
    NSMutableArray *localizedNames = [NSMutableArray arrayWithCapacity:listenerNames.count];
    for (NSString *listenerName in listenerNames) {
        [localizedNames addObject:[self localizedTitleForListenerName:listenerName]];
    }
    return [localizedNames componentsJoinedByString:@", "];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [self localizedStringForKey:eventName value:[dataSource localizedGroupForEventName:eventName]];
    }
    return @"";
}

- (NSString *)localizedGroupForListenerName:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedGroupForListenerName:)]) {
        return [self localizedStringForKey:listenerName
                                     value:[listener activator:self
                                               requiresLocalizedGroupForListenerName:listenerName]];
    }
    return @"";
}

- (NSString *)localizedDescriptionForEventMode:(NSString *)eventMode {
    return [self localizedTitleForEventMode:eventMode];
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    id<LAEventDataSource> dataSource = [self eventDataSourceForEventName:eventName];
    if (dataSource) {
        return [self localizedStringForKey:eventName value:[dataSource localizedDescriptionForEventName:eventName]];
    }
    return [self localizedTitleForEventName:eventName];
}

- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName {
    id<LAListener> listener = [self listenerForName:listenerName];
    if (listener && [listener respondsToSelector:@selector(activator:requiresLocalizedDescriptionForListenerName:)]) {
        return [self localizedStringForKey:listenerName
                                     value:[listener activator:self
                                               requiresLocalizedDescriptionForListenerName:listenerName]];
    }
    return [self localizedTitleForListenerName:listenerName];
}

@end
