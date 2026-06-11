//
//  LARuntimeStateProvider.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LARuntimeStateProvider : NSObject

#pragma mark - Runtime Updates

- (void)noteHomeScreenVisible:(BOOL)visible;
- (void)noteHomeScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteSpringBoardInterfaceVisible:(BOOL)visible source:(NSString *)source;
- (void)noteLockScreenVisible:(BOOL)visible;
- (void)noteLockScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)noteScreenBlanked:(BOOL)blanked;
- (void)noteRuntimeStateMayHaveChanged;

#pragma mark - State Queries

- (void)setEventModeChangeHandler:(nullable void (^)(NSString *eventMode))handler;
- (NSString *)currentEventMode;
- (NSString *)currentEventModeUnderneathLockScreen;
- (BOOL)screenIsOn;
- (BOOL)supportsUnlockingDeviceToSendEvents;
- (nullable NSString *)displayIdentifierForCurrentApplication;

#pragma mark - Testing

#if LA_TESTING
- (NSDictionary<NSString *, id> *)testingDebugDictionary;
#endif

@end

NS_ASSUME_NONNULL_END
