//
//  LATestTestingProtocols.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LAActivator;
@class LAEvent;

#pragma mark - Built-in Listener Metadata

@protocol LATestBuiltInListenerAllowlist <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
@end

@protocol LATestSelectorBackedBuiltInListener <LATestBuiltInListenerAllowlist>
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator;
@end

@protocol LATestTelephonyActionListener <LATestSelectorBackedBuiltInListener, LAListener>
- (BOOL)shouldHandleListenerName:(NSString *)listenerName activator:(nullable LAActivator *)activator;
@end

@protocol LATestURLActionListener <LATestBuiltInListenerAllowlist>
+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator;
- (nullable NSString *)urlStringForListenerName:(NSString *)listenerName activator:(LAActivator *)activator;
- (nullable NSString *)urlStringInURLsValue:(id)value;
- (nullable NSURL *)URLForListenerName:(NSString *)listenerName activator:(nullable LAActivator *)activator;
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName;
@end

#pragma mark - Dynamic Application Descriptor

@protocol LATestDynamicApplicationDescriptor <NSObject>
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *displayName;
- (BOOL)isVisibleApplication;
- (BOOL)isSystemApplication;
- (BOOL)isUserApplication;
- (BOOL)isWebClip;
- (nullable NSString *)applicationGroup;
@end

#pragma mark - Dynamic Application Factories

@protocol LATestDynamicApplicationDescriptorFactory <NSObject>
+ (id<LATestDynamicApplicationDescriptor>)descriptorWithIdentifier:(NSString *)identifier
                                                       displayName:(NSString *)displayName
                                                   applicationType:(NSString *)applicationType
                                                           appTags:(NSArray<NSString *> *)appTags
                                                     recordAppTags:(NSArray<NSString *> *)recordAppTags
                                                     bundleAppTags:(NSArray<NSString *> *)bundleAppTags
                                                  launchProhibited:(BOOL)launchProhibited;
@end

@protocol LATestDynamicApplicationProvider <NSObject>
+ (NSArray<id<LATestDynamicApplicationDescriptor>> *)visibleApplicationDescriptors;
@end

@protocol LATestDynamicApplicationActionListener <LAListener>
- (instancetype)initWithLauncher:(nullable id)launcher registry:(nullable id)registry;
- (void)setApplicationDescriptors:(NSDictionary<NSString *, id<LATestDynamicApplicationDescriptor>> *)descriptorsByIdentifier;
- (BOOL)shouldHandleApplicationDescriptor:(nullable id<LATestDynamicApplicationDescriptor>)descriptor
                                 forEvent:(LAEvent *)event
                                activator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
