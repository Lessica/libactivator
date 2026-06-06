//
//  LAEventDataSource.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Event Data Sources represent the metadata associated with specific events
// A data source is constructed automatically for each event in /Library/Activator/Events

@protocol LAEventDataSource <NSObject>

@required
- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;

@optional
- (BOOL)eventWithNameIsHidden:(NSString *)eventName;
- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(nullable NSString *)eventMode;
- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName;

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName;
- (void)removeEventWithName:(NSString *)eventName;

// LAEventConfigurationViewController
- (nullable NSString *)configurationViewControllerClassNameForEventWithName:(NSString *)eventName
                                                                     bundle:(NSBundle *_Nullable *_Nullable)bundle;

- (nullable id)configurationForEventWithName:(NSString *)eventName;
- (void)eventWithName:(NSString *)eventName didSaveNewConfiguration:(id)configuration;

@end

NS_ASSUME_NONNULL_END
