#import <Activator/Activator.h>
#import <dispatch/dispatch.h>

#import "LAActivatorBackend.h"
#import "LAActivatorPersistence.h"

#pragma mark - Class Extension

@interface LAActivator ()
@property(nonatomic, strong) LAActivatorBackend *backend;
@end

@implementation LAActivator

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
        _backend = [[LAActivatorBackend alloc] initWithAuthoritativeRole:self.runningInsideSpringBoard
                                                              persistence:[LAActivatorPersistence defaultPersistence]];
    }
    return self;
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
    return [self.backend listenerForName:name];
}

- (BOOL)hasListenerWithName:(NSString *)name {
    return [self.backend hasListenerWithName:name];
}

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name {
    if ([self.backend registerListener:listener forName:name]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                          object:self];
    }
}

- (void)unregisterListenerWithName:(NSString *)name {
    if ([self.backend unregisterListenerWithName:name]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableListenersChangedNotification
                                                          object:self];
    }
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
    if ([self.backend assignEvent:event toListenersWithNames:listenerNames]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
    }
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
    if ([self.backend unassignEvent:event]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAssignmentsChangedNotification object:self];
    }
}

- (NSString *)assignedListenerNameForEvent:(LAEvent *)event {
    return [[self assignedListenerNamesForEvent:event] firstObject];
}

- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event {
    return [self.backend assignedListenerNamesForEvent:event];
}

- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName {
    return [self.backend eventsAssignedToListenerWithName:listenerName];
}

#pragma mark - Event Registry

- (NSArray *)availableEventNames {
    return [self.backend availableEventNames];
}

- (BOOL)hasEventWithName:(NSString *)name {
    return [self.backend hasEventWithName:name];
}

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName {
    return [self.backend eventDataSourceForEventName:eventName];
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
    if ([self.backend registerEventDataSource:dataSource forEventName:eventName]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification object:self];
    }
}

- (void)unregisterEventDataSourceWithEventName:(NSString *)eventName {
    if ([self.backend unregisterEventDataSourceWithEventName:eventName]) {
        [NSNotificationCenter.defaultCenter postNotificationName:LAActivatorAvailableEventsChangedNotification object:self];
    }
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
    return [self.backend availableListenerNames];
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
        return [LAActivatorBackend normalizedStringArray:[listener activator:self
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
        return [LAActivatorBackend normalizedStringArray:[listener activator:self
                                                            requiresExclusiveAssignmentGroupsForListenerName:listenerName]];
    }
    return @[];
}

- (BOOL)listenerNamesAreMutuallyCompatible:(NSArray *)listenerNames {
    NSArray *normalizedNames = [LAActivatorBackend normalizedStringArray:listenerNames];
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
    return [self.backend applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier];
}

- (void)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted {
    [self.backend setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:blacklisted];
}

#pragma mark - Profiles

- (NSArray *)availableProfileNames {
    return [self.backend availableProfileNames];
}

- (NSString *)currentProfileName {
    return self.backend.currentProfileName;
}

- (void)setCurrentProfileName:(NSString *)currentProfileName {
    self.backend.currentProfileName = currentProfileName;
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
