#import <Activator/Activator.h>

__attribute__((visibility("hidden")))
@interface LADefaultEventDataSource : NSObject <LAEventDataSource>
+ (instancetype)sharedDataSource;
- (void)registerAvailableEventsWithActivator:(LAActivator *)activator;
@end
