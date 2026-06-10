//
//  LAActivatorResourceManager.h
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface LAActivatorResourceManager : NSObject

#pragma mark - Lifecycle

+ (instancetype)sharedManager;

#pragma mark - Paths And Bundles

- (NSString *)supportDirectoryPath;
- (NSString *)eventsDirectoryPath;
- (NSString *)listenersDirectoryPath;
- (nullable NSBundle *)supportBundle;

#pragma mark - Event Resources

- (nullable NSBundle *)eventBundleForName:(NSString *)eventName;
- (nullable NSBundle *)configurationBundleForEventName:(NSString *)eventName;
- (nullable NSDictionary<NSString *, id> *)eventInfoDictionaryForName:(NSString *)eventName;
- (NSArray<NSString *> *)availableEventNames;
- (BOOL)eventBundleIsCompatibleForName:(NSString *)eventName;

#pragma mark - Listener Resources

- (nullable NSBundle *)listenerBundleForName:(NSString *)listenerName;
- (nullable NSDictionary<NSString *, id> *)listenerInfoDictionaryForName:(NSString *)listenerName;
- (nullable id)infoDictionaryValueOfKey:(NSString *)key forListenerName:(NSString *)listenerName;
- (nullable NSString *)resolvedPathForResourcePath:(NSString *)path;

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value;
- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;
- (NSString *)localizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)localizedGroupForListenerName:(NSString *)listenerName;
- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName;

#pragma mark - Listener Icons

- (nullable NSData *)iconDataForListenerName:(NSString *)listenerName small:(BOOL)small scale:(nullable CGFloat *)scale;
- (nullable UIImage *)iconForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
