//
//  LATEventSourceRegistry.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventSourceRegistry.h"

#import "LAActivator+Private.h"
#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface LATEventSourceRegistry ()

@property(nonatomic, weak) LAActivator *activator;

@property(nonatomic, strong) NSMutableArray<id<LATEventSource>> *orderedEventSources;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<LATEventSource>> *eventSourcesByIdentifier;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSMutableArray<id<LATEventSource>> *> *eventSourcesByEventName;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, NSString *> *identifiersByEventSource;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, NSSet<NSString *> *> *eventNamesByEventSource;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, NSSet<NSString *> *> *interestEventNamesByEventSource;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, NSSet<NSString *> *> *interestedEventNamesByEventSource;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, id<LAEventDataSource>> *definitionDataSourcesByEventSource;
@property(nonatomic, strong) NSMapTable<id<LATEventSource>, NSSet<NSString *> *> *definitionEventNamesByEventSource;
@property(nonatomic, strong)
    NSMapTable<id<LAEventDataSource>, NSMutableSet<NSString *> *> *ownedDefinitionNamesByDataSource;
@property(nonatomic, strong) NSHashTable<id<LATEventSource>> *startedEventSources;
@property(nonatomic, strong) NSHashTable<id<LATEventSource>> *invalidatedEventSources;

@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;

@end

@implementation LATEventSourceRegistry

#pragma mark - Lifecycle

- (instancetype)initWithActivator:(LAActivator *)activator {
    LAAssertMainQueue();
    NSParameterAssert(activator);

    self = [super init];
    if (self) {
        _activator = activator;
        _orderedEventSources = [[NSMutableArray alloc] init];
        _eventSourcesByIdentifier = [[NSMutableDictionary alloc] init];
        _eventSourcesByEventName = [[NSMutableDictionary alloc] init];

        NSPointerFunctionsOptions sourceKeyOptions =
            NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality;
        _identifiersByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                              valueOptions:NSPointerFunctionsStrongMemory
                                                                  capacity:0];
        _eventNamesByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                             valueOptions:NSPointerFunctionsStrongMemory
                                                                 capacity:0];
        _interestEventNamesByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                                     valueOptions:NSPointerFunctionsStrongMemory
                                                                         capacity:0];
        _interestedEventNamesByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                                       valueOptions:NSPointerFunctionsStrongMemory
                                                                           capacity:0];
        _definitionDataSourcesByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                                        valueOptions:NSPointerFunctionsStrongMemory
                                                                            capacity:0];
        _definitionEventNamesByEventSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                                       valueOptions:NSPointerFunctionsStrongMemory
                                                                           capacity:0];
        _ownedDefinitionNamesByDataSource = [[NSMapTable alloc] initWithKeyOptions:sourceKeyOptions
                                                                      valueOptions:NSPointerFunctionsStrongMemory
                                                                          capacity:0];
        _startedEventSources = [[NSHashTable alloc] initWithOptions:sourceKeyOptions capacity:0];
        _invalidatedEventSources = [[NSHashTable alloc]
            initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
                   capacity:0];
    }
    return self;
}

- (void)dealloc {
    if (!self.invalidated) {
        [self invalidate];
    } else {
        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

- (void)start {
    LAAssertMainQueue();
    if (self.invalidated) {
        HBLogWarn(@"Ignoring start for an invalidated event source registry");
        return;
    }
    if (self.started) {
        return;
    }
    self.started = YES;

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    NSArray<NSString *> *notificationNames = @[
        LAActivatorAssignmentsChangedNotification,
        LAActivatorEventModeChangedNotification,
        LAActivatorAvailableEventsChangedNotification,
        LAActivatorAvailableListenersChangedNotification,
        LAActivatorListenerRegistryChangedNotification,
    ];
    for (NSString *notificationName in notificationNames) {
        [center addObserver:self
                   selector:@selector(interestInputsDidChange:)
                       name:notificationName
                     object:self.activator];
    }

    for (id<LATEventSource> eventSource in [self.orderedEventSources copy]) {
        [self startEventSourceIfNeeded:eventSource];
    }
    [self updateInterestForAllEventSourcesResettingRecognition:NO];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.invalidated) {
        return;
    }
    self.invalidated = YES;
    self.started = NO;
    [NSNotificationCenter.defaultCenter removeObserver:self];

    NSArray<id<LATEventSource>> *eventSources = [self.orderedEventSources.reverseObjectEnumerator allObjects];
    NSHashTable<id<LATEventSource>> *previouslyInterestedEventSources =
        [[NSHashTable alloc] initWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                    capacity:eventSources.count];
    for (id<LATEventSource> eventSource in eventSources) {
        if ([self.interestedEventNamesByEventSource objectForKey:eventSource].count > 0) {
            [previouslyInterestedEventSources addObject:eventSource];
        }
    }

    NSMutableArray<id<LAEventDataSource>> *ownedDefinitionDataSources = [[NSMutableArray alloc] init];
    NSMutableArray<NSSet<NSString *> *> *ownedDefinitionNames = [[NSMutableArray alloc] init];
    for (id<LAEventDataSource> definitionDataSource in self.ownedDefinitionNamesByDataSource.keyEnumerator) {
        [ownedDefinitionDataSources addObject:definitionDataSource];
        [ownedDefinitionNames
            addObject:[[self.ownedDefinitionNamesByDataSource objectForKey:definitionDataSource] copy]];
    }

    [self.orderedEventSources removeAllObjects];
    [self.eventSourcesByIdentifier removeAllObjects];
    [self.eventSourcesByEventName removeAllObjects];
    [self.identifiersByEventSource removeAllObjects];
    [self.eventNamesByEventSource removeAllObjects];
    [self.interestEventNamesByEventSource removeAllObjects];
    [self.interestedEventNamesByEventSource removeAllObjects];
    [self.definitionDataSourcesByEventSource removeAllObjects];
    [self.definitionEventNamesByEventSource removeAllObjects];
    [self.startedEventSources removeAllObjects];
    [self.invalidatedEventSources removeAllObjects];

    for (id<LATEventSource> eventSource in eventSources) {
        if ([previouslyInterestedEventSources containsObject:eventSource]) {
            [self notifyEventSource:eventSource interested:NO];
        }
        [eventSource invalidate];
        [self detachRegistryFromEventSource:eventSource];
    }
    [ownedDefinitionDataSources enumerateObjectsUsingBlock:^(id<LAEventDataSource> definitionDataSource,
                                                             NSUInteger index, __unused BOOL *stop) {
        for (NSString *eventName in ownedDefinitionNames[index]) {
            [self.activator la_unregisterEventDataSourceWithEventName:eventName
                                                  ifOwnedByDataSource:definitionDataSource];
        }
    }];
    [self.ownedDefinitionNamesByDataSource removeAllObjects];
}

#pragma mark - Registration

- (BOOL)registerEventSource:(id<LATEventSource>)eventSource {
    return [self registerEventSource:eventSource definitionDataSource:nil];
}

- (BOOL)registerEventSource:(id<LATEventSource>)eventSource
       definitionDataSource:(id<LAEventDataSource>)definitionDataSource {
    LAAssertMainQueue();
    if (self.invalidated || !eventSource || [self.invalidatedEventSources containsObject:eventSource]) {
        return NO;
    }

    NSString *identifier = eventSource.eventSourceIdentifier;
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0) {
        HBLogWarn(@"Skipping %@ because its event source identifier is empty", NSStringFromClass(eventSource.class));
        return NO;
    }

    LATEventSourceInterestPolicy interestPolicy = eventSource.interestPolicy;
    if (interestPolicy != LATEventSourceInterestPolicyAlways &&
        interestPolicy != LATEventSourceInterestPolicyAssignedInCurrentMode) {
        HBLogWarn(@"Skipping event source %@ because it has an unsupported interest policy", identifier);
        return NO;
    }

    NSString *registeredIdentifier = [self.identifiersByEventSource objectForKey:eventSource];
    if (registeredIdentifier) {
        if (![registeredIdentifier isEqualToString:identifier]) {
            HBLogWarn(@"Event source %@ cannot change its identifier from %@ to %@",
                      NSStringFromClass(eventSource.class), registeredIdentifier, identifier);
            return NO;
        }
        if ([self.definitionDataSourcesByEventSource objectForKey:eventSource] != definitionDataSource) {
            HBLogWarn(@"Event source %@ cannot change its definition data source", identifier);
            return NO;
        }
        return [self reloadEventNamesForEventSource:eventSource];
    }

    id<LATEventSource> registeredEventSource = self.eventSourcesByIdentifier[identifier];
    if (registeredEventSource && registeredEventSource != eventSource) {
        HBLogWarn(@"Skipping %@ because event source identifier %@ is already registered by %@",
                  NSStringFromClass(eventSource.class), identifier, NSStringFromClass(registeredEventSource.class));
        return NO;
    }

    NSString *identifierSnapshot = [identifier copy];
    NSSet<NSString *> *eventNamesSnapshot = [self normalizedEventNames:eventSource.eventNames];
    if (eventNamesSnapshot.count == 0) {
        HBLogWarn(@"Skipping event source %@ because it does not declare any event names", identifier);
        return NO;
    }
    NSSet<NSString *> *interestEventNamesSnapshot =
        [self normalizedInterestEventNamesForEventSource:eventSource fallbackEventNames:eventNamesSnapshot];
    NSSet<NSString *> *definitionEventNamesSnapshot =
        [self normalizedDefinitionEventNamesForEventSource:eventSource
                                        fallbackEventNames:eventNamesSnapshot
                                                dataSource:definitionDataSource];
    if (![definitionEventNamesSnapshot isSubsetOfSet:eventNamesSnapshot]) {
        HBLogWarn(@"Skipping event source %@ because its dynamic definitions are outside its producer catalog",
                  identifier);
        return NO;
    }
    NSArray<NSString *> *newlyRegisteredDefinitionNames =
        [self registerMissingDefinitionsForEventNames:definitionEventNamesSnapshot dataSource:definitionDataSource];
    if (definitionDataSource && !newlyRegisteredDefinitionNames) {
        return NO;
    }
    self.eventSourcesByIdentifier[identifierSnapshot] = eventSource;
    [self.orderedEventSources addObject:eventSource];
    [self.identifiersByEventSource setObject:identifierSnapshot forKey:eventSource];
    [self.eventNamesByEventSource setObject:eventNamesSnapshot forKey:eventSource];
    [self.interestEventNamesByEventSource setObject:interestEventNamesSnapshot forKey:eventSource];
    [self.interestedEventNamesByEventSource setObject:[NSSet set] forKey:eventSource];
    if (definitionDataSource) {
        [self.definitionDataSourcesByEventSource setObject:definitionDataSource forKey:eventSource];
        [self.definitionEventNamesByEventSource setObject:definitionEventNamesSnapshot forKey:eventSource];
    }
    [self attachRegistryToEventSource:eventSource];
    [self rebuildEventSourcesByEventName];

    if (self.started) {
        [self startEventSourceIfNeeded:eventSource];
        if ([self eventSourceIsRegistered:eventSource]) {
            [self updateInterestForEventSource:eventSource resettingRecognition:NO];
        }
    }
    return YES;
}

- (BOOL)unregisterEventSource:(id<LATEventSource>)eventSource {
    LAAssertMainQueue();
    if (!eventSource) {
        return NO;
    }

    NSString *identifier = [self.identifiersByEventSource objectForKey:eventSource];
    if (identifier.length == 0 || self.eventSourcesByIdentifier[identifier] != eventSource) {
        return NO;
    }

    BOOL wasInterested = [self.interestedEventNamesByEventSource objectForKey:eventSource].count > 0;
    id<LAEventDataSource> definitionDataSource = [self.definitionDataSourcesByEventSource objectForKey:eventSource];
    NSSet<NSString *> *previousDefinitionEventNames =
        [self.definitionEventNamesByEventSource objectForKey:eventSource] ?: [NSSet set];
    [self.eventSourcesByIdentifier removeObjectForKey:identifier];
    [self.orderedEventSources removeObjectIdenticalTo:eventSource];
    [self.identifiersByEventSource removeObjectForKey:eventSource];
    [self.eventNamesByEventSource removeObjectForKey:eventSource];
    [self.interestEventNamesByEventSource removeObjectForKey:eventSource];
    [self.interestedEventNamesByEventSource removeObjectForKey:eventSource];
    [self.definitionDataSourcesByEventSource removeObjectForKey:eventSource];
    [self.definitionEventNamesByEventSource removeObjectForKey:eventSource];
    [self.startedEventSources removeObject:eventSource];
    [self.invalidatedEventSources addObject:eventSource];
    [self rebuildEventSourcesByEventName];

    if (wasInterested) {
        [self notifyEventSource:eventSource interested:NO];
    }
    [eventSource invalidate];
    [self detachRegistryFromEventSource:eventSource];
    [self unregisterUnreferencedDefinitionsForEventNames:previousDefinitionEventNames dataSource:definitionDataSource];
    return YES;
}

- (BOOL)reloadEventNamesForEventSource:(id<LATEventSource>)eventSource {
    LAAssertMainQueue();
    if (self.invalidated || ![self eventSourceIsRegistered:eventSource]) {
        return NO;
    }

    NSSet<NSString *> *eventNamesSnapshot = [self normalizedEventNames:eventSource.eventNames];
    if (eventNamesSnapshot.count == 0) {
        HBLogWarn(@"Keeping the previous event names for %@ because the reloaded set is empty",
                  [self.identifiersByEventSource objectForKey:eventSource]);
        return NO;
    }
    NSSet<NSString *> *interestEventNamesSnapshot =
        [self normalizedInterestEventNamesForEventSource:eventSource fallbackEventNames:eventNamesSnapshot];
    NSSet<NSString *> *previousEventNames = [self.eventNamesByEventSource objectForKey:eventSource];
    id<LAEventDataSource> definitionDataSource = [self.definitionDataSourcesByEventSource objectForKey:eventSource];
    NSSet<NSString *> *previousDefinitionEventNames =
        [self.definitionEventNamesByEventSource objectForKey:eventSource] ?: [NSSet set];
    NSSet<NSString *> *definitionEventNamesSnapshot =
        [self normalizedDefinitionEventNamesForEventSource:eventSource
                                        fallbackEventNames:eventNamesSnapshot
                                                dataSource:definitionDataSource];
    if (![definitionEventNamesSnapshot isSubsetOfSet:eventNamesSnapshot]) {
        HBLogWarn(@"Keeping the previous event names for %@ because its dynamic definitions are outside its producer "
                   "catalog",
                  [self.identifiersByEventSource objectForKey:eventSource]);
        return NO;
    }
    NSArray<NSString *> *newlyRegisteredDefinitionNames =
        [self registerMissingDefinitionsForEventNames:definitionEventNamesSnapshot dataSource:definitionDataSource];
    if (definitionDataSource && !newlyRegisteredDefinitionNames) {
        return NO;
    }
    if (![previousEventNames isEqualToSet:eventNamesSnapshot]) {
        [self.eventNamesByEventSource setObject:eventNamesSnapshot forKey:eventSource];
        [self rebuildEventSourcesByEventName];
    }
    [self.interestEventNamesByEventSource setObject:interestEventNamesSnapshot forKey:eventSource];
    if (definitionDataSource) {
        [self.definitionEventNamesByEventSource setObject:definitionEventNamesSnapshot forKey:eventSource];
    }

    if (self.started) {
        [self updateInterestForEventSource:eventSource resettingRecognition:NO];
    }
    NSMutableSet<NSString *> *removedEventNames = [previousDefinitionEventNames mutableCopy];
    [removedEventNames minusSet:definitionEventNamesSnapshot];
    [self unregisterUnreferencedDefinitionsForEventNames:removedEventNames dataSource:definitionDataSource];
    return YES;
}

#pragma mark - Queries

- (NSArray<id<LATEventSource>> *)eventSources {
    LAAssertMainQueue();
    return [self.orderedEventSources copy];
}

- (NSArray<id<LATEventSource>> *)eventSourcesForEventName:(NSString *)eventName {
    LAAssertMainQueue();
    if (eventName.length == 0) {
        return @[];
    }
    return [self.eventSourcesByEventName[eventName] copy] ?: @[];
}

- (NSSet<NSString *> *)interestedEventNamesForEventSource:(id<LATEventSource>)eventSource {
    LAAssertMainQueue();
    if (!self.started || self.invalidated || ![self eventSourceIsRegistered:eventSource] ||
        ![self.startedEventSources containsObject:eventSource]) {
        return [NSSet set];
    }

    return [self.interestedEventNamesByEventSource objectForKey:eventSource] ?: [NSSet set];
}

- (BOOL)isInterestedInEventSource:(id<LATEventSource>)eventSource {
    LAAssertMainQueue();
    if (!self.started || self.invalidated || ![self eventSourceIsRegistered:eventSource] ||
        ![self.startedEventSources containsObject:eventSource]) {
        return NO;
    }
    return [self.interestedEventNamesByEventSource objectForKey:eventSource].count > 0;
}

#pragma mark - Interest Updates

- (void)interestInputsDidChange:(NSNotification *)notification {
    BOOL resetRecognition = [notification.name isEqualToString:LAActivatorEventModeChangedNotification];
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updateInterestForAllEventSourcesResettingRecognition:resetRecognition];
        });
        return;
    }
    [self updateInterestForAllEventSourcesResettingRecognition:resetRecognition];
}

- (void)updateInterestForAllEventSourcesResettingRecognition:(BOOL)resetRecognition {
    LAAssertMainQueue();
    if (!self.started || self.invalidated) {
        return;
    }
    for (id<LATEventSource> eventSource in [self.orderedEventSources copy]) {
        [self updateInterestForEventSource:eventSource resettingRecognition:resetRecognition];
    }
}

- (void)updateInterestForEventSource:(id<LATEventSource>)eventSource resettingRecognition:(BOOL)resetRecognition {
    LAAssertMainQueue();
    if (![self eventSourceIsRegistered:eventSource] || ![self.startedEventSources containsObject:eventSource]) {
        return;
    }

    NSSet<NSString *> *interestedEventNames = [self calculateInterestedEventNamesForEventSource:eventSource];
    NSSet<NSString *> *previousInterestedEventNames =
        [self.interestedEventNamesByEventSource objectForKey:eventSource] ?: [NSSet set];
    BOOL interested = interestedEventNames.count > 0;
    BOOL wasInterested = previousInterestedEventNames.count > 0;
    [self.interestedEventNamesByEventSource setObject:interestedEventNames forKey:eventSource];
    BOOL interestedEventNamesChanged = ![previousInterestedEventNames isEqualToSet:interestedEventNames];
    BOOL shouldResetRecognition =
        resetRecognition && eventSource.interestPolicy == LATEventSourceInterestPolicyAssignedInCurrentMode;
    if ((interestedEventNamesChanged || shouldResetRecognition) &&
        [eventSource respondsToSelector:@selector(eventSourceInterestedEventNamesDidChange:)]) {
        [eventSource eventSourceInterestedEventNamesDidChange:interestedEventNames];
    }
    if (interested == wasInterested) {
        return;
    }

    [self notifyEventSource:eventSource interested:interested];
}

- (NSSet<NSString *> *)calculateInterestedEventNamesForEventSource:(id<LATEventSource>)eventSource {
    NSSet<NSString *> *eventNames = [self.interestEventNamesByEventSource objectForKey:eventSource] ?: [NSSet set];
    LAActivator *activator = self.activator;
    if (!activator) {
        return [NSSet set];
    }

    NSMutableSet<NSString *> *availableEventNames = [[NSMutableSet alloc] initWithCapacity:eventNames.count];
    for (NSString *eventName in eventNames) {
        if ([activator hasEventWithName:eventName]) {
            [availableEventNames addObject:eventName];
        }
    }
    if (eventSource.interestPolicy == LATEventSourceInterestPolicyAlways) {
        return [availableEventNames copy];
    }

    NSString *eventMode = activator.currentEventMode;
    if (eventMode.length == 0) {
        return [NSSet set];
    }

    NSMutableSet<NSString *> *interestedEventNames = [[NSMutableSet alloc] init];
    for (NSString *eventName in availableEventNames) {
        LAEvent *event = [LAEvent eventWithName:eventName mode:eventMode];
        if ([activator assignedListenerNamesForEvent:event].count > 0) {
            [interestedEventNames addObject:eventName];
        }
    }
    return [interestedEventNames copy];
}

#pragma mark - Dynamic Definitions

- (nullable NSArray<NSString *> *)registerMissingDefinitionsForEventNames:(NSSet<NSString *> *)eventNames
                                                               dataSource:(nullable id<LAEventDataSource>)dataSource {
    if (!dataSource) {
        return @[];
    }

    LAActivator *activator = self.activator;
    if (!activator) {
        return nil;
    }
    NSArray<NSString *> *orderedEventNames = [eventNames.allObjects sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *eventName in orderedEventNames) {
        id<LAEventDataSource> registeredDataSource = [activator eventDataSourceForEventName:eventName];
        if (registeredDataSource && registeredDataSource != dataSource) {
            HBLogWarn(@"Unable to register dynamic definition %@ because it is owned by %@", eventName,
                      NSStringFromClass(registeredDataSource.class));
            return nil;
        }
    }

    NSMutableArray<NSString *> *newlyRegisteredEventNames = [[NSMutableArray alloc] init];
    for (NSString *eventName in orderedEventNames) {
        if ([activator eventDataSourceForEventName:eventName] == dataSource) {
            continue;
        }
        if (![activator la_registerEventDataSourceIfAbsent:dataSource forEventName:eventName]) {
            for (NSString *registeredEventName in newlyRegisteredEventNames) {
                [activator la_unregisterEventDataSourceWithEventName:registeredEventName
                                                 ifOwnedByDataSource:dataSource];
            }
            return nil;
        }
        [newlyRegisteredEventNames addObject:eventName];
    }
    if (newlyRegisteredEventNames.count > 0) {
        NSMutableSet<NSString *> *ownedEventNames = [self.ownedDefinitionNamesByDataSource objectForKey:dataSource];
        if (!ownedEventNames) {
            ownedEventNames = [[NSMutableSet alloc] init];
            [self.ownedDefinitionNamesByDataSource setObject:ownedEventNames forKey:dataSource];
        }
        [ownedEventNames addObjectsFromArray:newlyRegisteredEventNames];
    }
    return [newlyRegisteredEventNames copy];
}

- (void)unregisterUnreferencedDefinitionsForEventNames:(NSSet<NSString *> *)eventNames
                                            dataSource:(nullable id<LAEventDataSource>)dataSource {
    if (!dataSource || eventNames.count == 0) {
        return;
    }
    NSMutableSet<NSString *> *ownedEventNames = [self.ownedDefinitionNamesByDataSource objectForKey:dataSource];
    for (NSString *eventName in eventNames) {
        if (![ownedEventNames containsObject:eventName]) {
            continue;
        }
        BOOL stillReferenced = NO;
        for (id<LATEventSource> eventSource in self.orderedEventSources) {
            if ([self.definitionDataSourcesByEventSource objectForKey:eventSource] == dataSource &&
                [[self.definitionEventNamesByEventSource objectForKey:eventSource] containsObject:eventName]) {
                stillReferenced = YES;
                break;
            }
        }
        if (!stillReferenced) {
            [self.activator la_unregisterEventDataSourceWithEventName:eventName ifOwnedByDataSource:dataSource];
            [ownedEventNames removeObject:eventName];
        }
    }
    if (ownedEventNames.count == 0) {
        [self.ownedDefinitionNamesByDataSource removeObjectForKey:dataSource];
    }
}

- (void)notifyEventSource:(id<LATEventSource>)eventSource interested:(BOOL)interested {
    if ([eventSource respondsToSelector:@selector(eventSourceInterestDidChange:)]) {
        [eventSource eventSourceInterestDidChange:interested];
    }
}

#pragma mark - Source Ownership

- (void)startEventSourceIfNeeded:(id<LATEventSource>)eventSource {
    LAAssertMainQueue();
    if (self.invalidated || ![self eventSourceIsRegistered:eventSource] ||
        [self.startedEventSources containsObject:eventSource]) {
        return;
    }
    [self.startedEventSources addObject:eventSource];
    [eventSource start];
}

- (void)attachRegistryToEventSource:(id<LATEventSource>)eventSource {
    if ([eventSource respondsToSelector:@selector(setEventSourceRegistry:)]) {
        eventSource.eventSourceRegistry = self;
    }
}

- (void)detachRegistryFromEventSource:(id<LATEventSource>)eventSource {
    if ([eventSource respondsToSelector:@selector(setEventSourceRegistry:)]) {
        eventSource.eventSourceRegistry = nil;
    }
}

#pragma mark - Indexes

- (BOOL)eventSourceIsRegistered:(id<LATEventSource>)eventSource {
    if (!eventSource) {
        return NO;
    }
    NSString *identifier = [self.identifiersByEventSource objectForKey:eventSource];
    return identifier.length > 0 && self.eventSourcesByIdentifier[identifier] == eventSource;
}

- (NSSet<NSString *> *)normalizedEventNames:(NSSet<NSString *> *)eventNames {
    if (![eventNames isKindOfClass:NSSet.class]) {
        return [NSSet set];
    }

    NSMutableSet<NSString *> *normalizedEventNames = [[NSMutableSet alloc] initWithCapacity:eventNames.count];
    for (id value in eventNames) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            [normalizedEventNames addObject:value];
        }
    }
    return [normalizedEventNames copy];
}

- (NSSet<NSString *> *)normalizedInterestEventNamesForEventSource:(id<LATEventSource>)eventSource
                                               fallbackEventNames:(NSSet<NSString *> *)eventNames {
    if (![eventSource respondsToSelector:@selector(interestEventNames)]) {
        return eventNames;
    }
    return [self normalizedEventNames:eventSource.interestEventNames];
}

- (NSSet<NSString *> *)normalizedDefinitionEventNamesForEventSource:(id<LATEventSource>)eventSource
                                                 fallbackEventNames:(NSSet<NSString *> *)eventNames
                                                         dataSource:(nullable id<LAEventDataSource>)dataSource {
    if (!dataSource) {
        return [NSSet set];
    }
    if (![eventSource respondsToSelector:@selector(definitionEventNames)]) {
        return eventNames;
    }
    return [self normalizedEventNames:eventSource.definitionEventNames];
}

- (void)rebuildEventSourcesByEventName {
    [self.eventSourcesByEventName removeAllObjects];
    for (id<LATEventSource> eventSource in self.orderedEventSources) {
        for (NSString *eventName in [self.eventNamesByEventSource objectForKey:eventSource]) {
            NSMutableArray<id<LATEventSource>> *eventSources = self.eventSourcesByEventName[eventName];
            if (!eventSources) {
                eventSources = [[NSMutableArray alloc] init];
                self.eventSourcesByEventName[eventName] = eventSources;
            }
            [eventSources addObject:eventSource];
        }
    }
}

@end
