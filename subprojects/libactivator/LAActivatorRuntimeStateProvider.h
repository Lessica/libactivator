//
//  LAActivatorRuntimeStateProvider.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAActivatorRuntimeStateProvider : NSObject
- (void)noteHomeScreenVisible:(BOOL)visible;
- (void)noteHomeScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteLockScreenVisible:(BOOL)visible;
- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteScreenBlanked:(BOOL)blanked;
- (void)noteRuntimeStateMayHaveChanged;
- (void)setEventModeChangeHandler:(nullable void (^)(NSString *eventMode))handler;
- (NSString *)currentEventMode;
- (NSString *)currentEventModeUnderneathLockScreen;
- (BOOL)supportsUnlockingDeviceToSendEvents;
- (nullable NSString *)displayIdentifierForCurrentApplication;
#if LA_TESTING
- (NSDictionary *)testingDebugDictionary;
#endif
@end

NS_ASSUME_NONNULL_END
