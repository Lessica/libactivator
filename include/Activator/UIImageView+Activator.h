//
//  UIImageView+Activator.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImageView (Activator)
@property(nonatomic, assign) BOOL activatorListenerImageIsThreaded;
@property(nonatomic, copy, nullable) NSString *activatorListenerName;
@end

NS_ASSUME_NONNULL_END
