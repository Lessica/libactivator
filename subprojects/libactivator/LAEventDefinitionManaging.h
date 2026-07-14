//
//  LAEventDefinitionManaging.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Catalog Schema

static NSString *const LAEventDefinitionCatalogGenerationKey = @"Generation";
static NSString *const LAEventDefinitionCatalogProvidersKey = @"Providers";
static NSString *const LAEventDefinitionCatalogProviderIdentifierKey = @"Identifier";
static NSString *const LAEventDefinitionCatalogEventNamesKey = @"EventNames";
static NSString *const LAEventDefinitionCatalogTemplatesKey = @"Templates";
static NSString *const LAEventDefinitionCatalogTemplateIdentifierKey = @"Identifier";
static NSString *const LAEventDefinitionCatalogTemplateTitleKey = @"Title";
static NSString *const LAEventDefinitionCatalogTemplateDescriptionKey = @"Description";

#pragma mark - Management Contract

@protocol LAEventDefinitionManaging <NSObject>

- (NSDictionary<NSString *, id> *)eventCreationCatalog;
- (nullable NSString *)createEventWithProviderIdentifier:(NSString *)providerIdentifier
                                      templateIdentifier:(NSString *)templateIdentifier
                                           configuration:(id)configuration
                                      expectedGeneration:(NSUInteger)expectedGeneration;
- (BOOL)removeEventWithName:(NSString *)eventName expectedGeneration:(NSUInteger)expectedGeneration;

@end

NS_ASSUME_NONNULL_END
