#import <Activator/Activator.h>

__attribute__((visibility("hidden")))
@interface LARemoteListener : NSObject <LAListener>
+ (instancetype)sharedListener;
@end
