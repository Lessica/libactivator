//
//  LATURLActionListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATURLActionListener : NSObject <LAListener>
@end

#if LA_TESTING
typedef BOOL (^LATURLActionOpenHandler)(NSURL *url, NSString *listenerName);

@interface LATURLActionListener (Testing)
+ (void)setTestingOpenHandler:(nullable LATURLActionOpenHandler)handler;
+ (void)setTestingURLMetadata:(nullable NSDictionary<NSString *, id> *)metadata
              forListenerName:(NSString *)listenerName;
+ (nullable NSURL *)testingLastOpenedURL;
+ (nullable NSString *)testingLastOpenedListenerName;
+ (void)resetTestingState;
@end
#endif

NS_ASSUME_NONNULL_END
