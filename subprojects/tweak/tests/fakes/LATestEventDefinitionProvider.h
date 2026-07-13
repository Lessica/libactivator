//
//  LATestEventDefinitionProvider.h
//  libactivator
//
//  Created by Lessica on 7/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATEventDefinitionProvider.h"
#import "LATestEventDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface LATestEventDefinitionProvider : LATestEventDataSource <LATEventDefinitionProvider>

@property(nonatomic, copy) NSString *eventDefinitionProviderIdentifier;
@property(nonatomic, copy) NSSet<NSString *> *eventDefinitionNames;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *eventCreationTemplates;
@property(nonatomic, weak, nullable) LATEventDefinitionRegistry *eventDefinitionRegistry;
@property(nonatomic, assign) NSUInteger mutationCount;
@property(nonatomic, assign) NSUInteger successfulMutationCount;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(NSString *)identifier
                        eventNames:(NSSet<NSString *> *)eventNames NS_DESIGNATED_INITIALIZER;

- (BOOL)replaceEventDefinitionNames:(NSSet<NSString *> *)eventNames;

@end

NS_ASSUME_NONNULL_END
