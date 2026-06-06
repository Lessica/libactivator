//
//  LAApplicationIconProvider.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAApplicationIconProvider : NSObject
+ (instancetype)sharedProvider;
- (nullable UIImage *)smallIconForDisplayIdentifier:(NSString *)displayIdentifier scale:(CGFloat)scale;
@end

NS_ASSUME_NONNULL_END
