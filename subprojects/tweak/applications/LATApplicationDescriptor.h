//
//  LATApplicationDescriptor.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATApplicationDescriptor : NSObject

#pragma mark - Properties

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, copy, readonly) NSString *applicationType;
@property(nonatomic, copy, readonly) NSArray<NSString *> *appTags;
@property(nonatomic, copy, readonly) NSArray<NSString *> *recordAppTags;
@property(nonatomic, copy, readonly) NSArray<NSString *> *bundleAppTags;
@property(nonatomic, assign, readonly, getter=isLaunchProhibited) BOOL launchProhibited;

#pragma mark - Factories

+ (nullable instancetype)descriptorWithApplicationProxy:(nullable id)applicationProxy;
+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                             displayName:(NSString *)displayName
                         applicationType:(NSString *)applicationType
                                 appTags:(NSArray<NSString *> *)appTags
                           recordAppTags:(NSArray<NSString *> *)recordAppTags
                           bundleAppTags:(NSArray<NSString *> *)bundleAppTags
                        launchProhibited:(BOOL)launchProhibited;

#pragma mark - Classification

- (BOOL)isVisibleApplication;
- (BOOL)isSystemApplication;
- (BOOL)isUserApplication;
- (BOOL)isWebClip;
- (nullable NSString *)applicationGroup;

@end

NS_ASSUME_NONNULL_END
