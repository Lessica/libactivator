//
//  LAPersistence.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAPersistence : NSObject

#pragma mark - Configuration

@property(nonatomic, copy, readonly) NSString *filePath;

#pragma mark - Lifecycle

+ (instancetype)defaultPersistence;
- (instancetype)initWithFilePath:(NSString *)filePath;

#pragma mark - Persistence

- (nullable NSDictionary<NSString *, id> *)loadDictionary;
- (BOOL)saveDictionary:(NSDictionary<NSString *, id> *)dictionary;

#pragma mark - Testing

#if DEBUG
+ (instancetype)testingPersistence;
#endif

@end

NS_ASSUME_NONNULL_END
