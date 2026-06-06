#import <Activator/Activator.h>

@class LAActivatorPersistence;

__attribute__((visibility("hidden")))
@interface LAActivatorBackend : NSObject

@property(nonatomic, assign, readonly, getter=isAuthoritative) BOOL authoritative;
@property(nonatomic, copy) NSString *currentProfileName;

- (instancetype)initWithAuthoritativeRole:(BOOL)authoritative persistence:(LAActivatorPersistence *)persistence;

- (id<LAListener>)listenerForName:(NSString *)name;
- (BOOL)hasListenerWithName:(NSString *)name;
- (BOOL)registerListener:(id<LAListener>)listener forName:(NSString *)name;
- (BOOL)unregisterListenerWithName:(NSString *)name;
- (NSArray *)availableListenerNames;
- (NSArray *)registeredListeners;

- (id<LAEventDataSource>)eventDataSourceForEventName:(NSString *)eventName;
- (BOOL)registerEventDataSource:(id<LAEventDataSource>)dataSource forEventName:(NSString *)eventName;
- (BOOL)unregisterEventDataSourceWithEventName:(NSString *)eventName;
- (NSArray *)availableEventNames;
- (BOOL)hasEventWithName:(NSString *)name;

- (BOOL)assignEvent:(LAEvent *)event toListenersWithNames:(NSArray *)listenerNames;
- (BOOL)unassignEvent:(LAEvent *)event;
- (NSArray *)assignedListenerNamesForEvent:(LAEvent *)event;
- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName;

- (BOOL)applicationWithDisplayIdentifierIsBlacklisted:(NSString *)displayIdentifier;
- (BOOL)setApplicationWithDisplayIdentifier:(NSString *)displayIdentifier isBlacklisted:(BOOL)blacklisted;
- (NSArray *)availableProfileNames;
- (BOOL)setCurrentProfileNameIfChanged:(NSString *)currentProfileName;

+ (NSArray *)normalizedStringArray:(NSArray *)array;

@end
