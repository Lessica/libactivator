//
//  LAListenerMetadataCache.h
//  libactivator
//
//  Created by Lessica on 6/9/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LAListenerMetadataCache : NSObject

- (void)removeAllObjects;
- (nullable UIImage *)smallIconForListenerName:(NSString *)listenerName resolver:(nullable UIImage *_Nullable (^)(void))resolver;
- (nullable NSString *)localizedTitleForListenerName:(NSString *)listenerName
                                            resolver:(nullable NSString *_Nullable (^)(void))resolver;
- (nullable NSString *)localizedGroupForListenerName:(NSString *)listenerName
                                            resolver:(nullable NSString *_Nullable (^)(void))resolver;
- (nullable NSString *)localizedDescriptionForListenerName:(NSString *)listenerName
                                                  resolver:(nullable NSString *_Nullable (^)(void))resolver;

@end

NS_ASSUME_NONNULL_END
