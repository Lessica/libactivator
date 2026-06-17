//
//  LATSystemSwitcherController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATMediaEventSource;
@class LATRuntimeStateSource;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemSwitcherController : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMediaEventSource:(LATMediaEventSource *_Nullable)mediaEventSource
                      runtimeStateSource:(LATRuntimeStateSource *_Nullable)runtimeStateSource NS_DESIGNATED_INITIALIZER;

- (BOOL)activateSwitcherForListenerName:(NSString *)listenerName;
- (BOOL)clearSwitcherForListenerName:(NSString *)listenerName;
- (BOOL)clearSwitcherForListenerName:(NSString *)listenerName
          skipsNowPlayingApplication:(BOOL)skipsNowPlayingApplication;

@end

NS_ASSUME_NONNULL_END
