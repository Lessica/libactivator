#import <Activator/Activator.h>

__attribute__((visibility("hidden")))
@interface LAActivatorResourceManager : NSObject
+ (instancetype)sharedManager;
- (NSBundle *)supportBundle;
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value;
- (NSBundle *)eventBundleForName:(NSString *)eventName;
- (NSDictionary *)eventInfoDictionaryForName:(NSString *)eventName;
- (NSArray *)availableEventNames;
- (BOOL)eventBundleIsCompatibleForName:(NSString *)eventName;
- (NSBundle *)listenerBundleForName:(NSString *)listenerName;
- (NSDictionary *)listenerInfoDictionaryForName:(NSString *)listenerName;
- (id)infoDictionaryValueOfKey:(NSString *)key forListenerName:(NSString *)listenerName;
- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;
- (NSString *)localizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)localizedGroupForListenerName:(NSString *)listenerName;
- (NSString *)localizedDescriptionForListenerName:(NSString *)listenerName;
- (NSData *)iconDataForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat *)scale;
- (UIImage *)iconForListenerName:(NSString *)listenerName small:(BOOL)small scale:(CGFloat)scale;
@end
