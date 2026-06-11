//
//  LATSystemNowPlayingApplicationLauncher.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATApplicationLauncher;
@class LATMediaEventSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemNowPlayingApplicationLauncher : NSObject
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher;
- (instancetype)initWithApplicationLauncher:(LATApplicationLauncher *)applicationLauncher
                           mediaEventSource:(LATMediaEventSource *_Nullable)mediaEventSource;
- (BOOL)launchNowPlayingApplicationForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
