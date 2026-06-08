//
//  LAActivatorPersistence.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAActivatorPersistence : NSObject

@property(nonatomic, copy, readonly) NSString *filePath;

+ (instancetype)defaultPersistence;
- (instancetype)initWithFilePath:(NSString *)filePath;
- (nullable NSDictionary *)loadDictionary;
- (BOOL)saveDictionary:(NSDictionary *)dictionary;

#if LA_TESTING
+ (instancetype)testingPersistence;
#endif

@end

NS_ASSUME_NONNULL_END
