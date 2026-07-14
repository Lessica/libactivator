//
//  LATestEventDefinitionProvider.m
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventDefinitionProvider.h"

#import "LAEventDefinitionManaging.h"
#import "LATEventDefinitionRegistry.h"

@implementation LATestEventDefinitionProvider

- (instancetype)initWithIdentifier:(NSString *)identifier eventNames:(NSSet<NSString *> *)eventNames {
    self = [super init];
    if (self) {
        _eventDefinitionProviderIdentifier = [identifier copy];
        _eventDefinitionNames = [eventNames copy];
        _eventCreationTemplates = @[ @{
            LAEventDefinitionCatalogTemplateIdentifierKey : @"testing",
            LAEventDefinitionCatalogTemplateTitleKey : @"Testing",
        } ];
    }
    return self;
}

- (id<LAEventDataSource>)eventDataSource {
    return self;
}

- (NSString *)createEventWithTemplateIdentifier:(NSString *)templateIdentifier configuration:(id)configuration {
    NSDictionary *configurationDictionary = [configuration isKindOfClass:NSDictionary.class] ? configuration : nil;
    NSString *eventName = [configurationDictionary[@"EventName"] isKindOfClass:NSString.class]
                              ? configurationDictionary[@"EventName"]
                              : nil;
    if (![templateIdentifier isEqualToString:@"testing"] || eventName.length == 0) {
        return nil;
    }
    if ([self.eventDefinitionNames containsObject:eventName]) {
        return eventName;
    }
    NSMutableSet<NSString *> *eventNames = [self.eventDefinitionNames mutableCopy];
    [eventNames addObject:eventName];
    return [self replaceEventDefinitionNames:eventNames] ? eventName : nil;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    return [self.eventDefinitionNames containsObject:eventName] &&
           [self.eventDefinitionRegistry providerForEventName:eventName] == self;
}

- (void)removeEventWithName:(NSString *)eventName {
    if (![self.eventDefinitionNames containsObject:eventName]) {
        return;
    }
    NSMutableSet<NSString *> *eventNames = [self.eventDefinitionNames mutableCopy];
    [eventNames removeObject:eventName];
    [self replaceEventDefinitionNames:eventNames];
}

- (BOOL)replaceEventDefinitionNames:(NSSet<NSString *> *)eventNames {
    self.mutationCount += 1;
    NSSet<NSString *> *previousEventNames = self.eventDefinitionNames;
    self.eventDefinitionNames = [eventNames copy];
    if (![self.eventDefinitionRegistry reloadEventNamesForProvider:self]) {
        self.eventDefinitionNames = previousEventNames;
        return NO;
    }
    self.successfulMutationCount += 1;
    return YES;
}

@end
