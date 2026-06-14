//
//  LARuntimeContext.h
//  libactivator
//
//  Created by Lessica on 6/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LARuntimeContext : NSObject

#pragma mark - Setters

- (nullable NSString *)updateEventMode:(NSString *)eventMode
                  underneathLockScreen:(NSString *)underneathMode
                     displayIdentifier:(nullable NSString *)displayIdentifier
                              screenOn:(BOOL)screenOn;

- (void)setEventModeChangeHandler:(nullable void (^)(NSString *eventMode))handler;
- (void)setTouchActivityProvider:(nullable BOOL (^)(void))touchActiveProvider
           touchesEndedPerformer:(nullable void (^)(dispatch_block_t block))touchesEndedPerformer;

#pragma mark - Getters

- (NSString *)currentEventMode;
- (NSString *)currentEventModeUnderneathLockScreen;
- (nullable NSString *)displayIdentifierForCurrentApplication;
- (BOOL)screenIsOn;
- (BOOL)touchActive;
- (void)performWhenTouchesEnd:(dispatch_block_t)block;

#pragma mark - Testing

#if DEBUG
- (NSDictionary<NSString *, id> *)testingDebugDictionary;
#endif

@end

NS_ASSUME_NONNULL_END
