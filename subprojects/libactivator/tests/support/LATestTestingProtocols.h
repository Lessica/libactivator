//
//  LATestTestingProtocols.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATestBuiltInListenerAllowlist <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
@end

@protocol LATestSelectorBackedBuiltInListener <LATestBuiltInListenerAllowlist>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (nullable NSString *)expectedSelectorForListenerName:(NSString *)listenerName;
@end

@protocol LATestDynamicApplicationDescriptor <NSObject>
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *displayName;
- (BOOL)isVisibleApplication;
- (BOOL)isSystemApplication;
- (BOOL)isUserApplication;
- (BOOL)isWebClip;
- (nullable NSString *)applicationGroup;
@end

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

NS_ASSUME_NONNULL_END
