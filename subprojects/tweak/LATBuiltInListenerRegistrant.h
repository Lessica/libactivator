//
//  LATBuiltInListenerRegistrant.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LATBuiltInListenerRegistrant <NSObject>
+ (NSArray<NSString *> *)supportedListenerNames;
+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator;
@end

NS_ASSUME_NONNULL_END
