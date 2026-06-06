#import <Activator/Activator.h>

@interface LAActivator (Private)
- (void)startIPCServerIfNeeded;
- (BOOL)la_assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)la_unassignEvent:(LAEvent *)event;
- (BOOL)la_setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (BOOL)la_setCurrentProfileName:(NSString *)currentProfileName;
@end
