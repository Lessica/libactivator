//
//  LAActivator+Private.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@class UIEvent;

@interface LAActivator (Private)
- (void)startIPCServerIfNeeded;
- (nullable id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(nullable id)value forPreference:(NSString *)preference;
- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen;
- (void)la_noteHomeScreenVisible:(BOOL)visible;
- (void)la_noteHomeScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)la_noteSpringBoardInterfaceVisible:(BOOL)visible source:(NSString *)source;
- (void)la_noteLockScreenVisible:(BOOL)visible;
- (void)la_noteLockScreenVisible:(BOOL)visible source:(NSString *)source;
- (void)la_noteScreenBlanked:(BOOL)blanked;
- (void)la_noteRuntimeStateMayHaveChanged;
- (void)la_noteSystemTouchEvent:(UIEvent *)event;
#if LA_TESTING
- (NSDictionary *)la_runtimeStateDebugDictionary;
#endif
- (nullable id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;
- (BOOL)la_assignEventAndNotifyIfChanged:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)la_addListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName toEvent:(LAEvent *)event;
- (BOOL)la_removeListenerAssignmentAndNotifyIfChanged:(NSString *)listenerName fromEvent:(LAEvent *)event;
- (BOOL)la_unassignEventAndNotifyIfChanged:(LAEvent *)event;
- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(nullable NSString *)currentProfileName;
- (nullable NSData *)la_smallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale;
- (void)la_sendEvent:(LAEvent *)event directlyToListenerWithName:(NSString *)listenerName abort:(BOOL)abort;
@end

NS_ASSUME_NONNULL_END
