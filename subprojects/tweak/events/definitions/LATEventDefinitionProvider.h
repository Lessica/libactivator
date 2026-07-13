//
//  LATEventDefinitionProvider.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATEventDefinitionRegistry;
@protocol LAEventDataSource;

NS_ASSUME_NONNULL_BEGIN

// Each template descriptor is a property-list dictionary with a required
// non-empty "Identifier" string. Remaining keys are provider-defined display
// metadata consumed by a future Settings host.
@protocol LATEventDefinitionProvider <NSObject>

@property(nonatomic, copy, readonly) NSString *eventDefinitionProviderIdentifier;
@property(nonatomic, copy, readonly) NSSet<NSString *> *eventDefinitionNames;
@property(nonatomic, strong, readonly) id<LAEventDataSource> eventDataSource;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *eventCreationTemplates;
@property(nonatomic, weak, nullable) LATEventDefinitionRegistry *eventDefinitionRegistry;

- (nullable NSString *)createEventWithTemplateIdentifier:(NSString *)templateIdentifier configuration:(id)configuration;

@end

NS_ASSUME_NONNULL_END
