//
//  LAActivatorPrivate.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LAActivator (Private)
- (void)startIPCServerIfNeeded;
- (BOOL)la_assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)la_unassignEvent:(LAEvent *)event;
- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(nullable NSString *)currentProfileName;
@end

NS_ASSUME_NONNULL_END
