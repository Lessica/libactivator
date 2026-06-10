//
//  LAActivatorTestSupport.m
//  libactivator
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#if LA_TESTING

#import "LAActivatorTestSupport.h"

#import "LAActivator+Private.h"
#import "LAActivatorBackend.h"
#import "LAActivatorIPC.h"
#import "LAActivatorPersistence.h"
#import "LAActivatorResourceManager.h"
#import "LATouchActivityTracker.h"

#import <Activator/Activator.h>
#import <IOKit/hid/IOHIDEvent.h>
#import <IOKit/hid/IOHIDEventSystemClient.h>
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <roothide.h>
#import <sys/stat.h>

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

static const IOHIDEventField LATestHIDEventFieldIsBuiltIn = IOHIDEventFieldBase(kIOHIDEventTypeNULL) + 4;
static const IOHIDEventField LATestHIDEventFieldDigitizerIsDisplayIntegrated = kIOHIDEventFieldDigitizerMajorRadius + 5;
static const uint64_t LATestHIDSenderID = 0x8000000817319371;

@interface UIApplication (LAActivatorTesting)
- (id)_accessibilityFrontMostApplication;
@end

@protocol LAActivatorTestingApplication <NSObject>
@optional
- (NSString *)bundleIdentifier;
- (NSString *)displayIdentifier;
@end

@interface SpringBoard : UIApplication
+ (instancetype)sharedApplication;
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
- (void)suspend;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)remoteLock:(BOOL)lock;
- (void)attemptUnlockWithPasscode:(NSString *)passcode;
- (void)attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)finishUIUnlock completion:(id)completion;
@end

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
- (void)_startFadeOutAnimationFromLockSource:(long long)source;
- (void)turnOnScreenFullyWithBacklightSource:(long long)source;
@end

@interface SBSTestAutomationService : NSObject
- (void)resetToHomeScreenAnimated:(BOOL)animated;
- (void)resetToHomeScreenAnimated:(BOOL)animated useSafeTransitions:(BOOL)useSafeTransitions;
@end

@interface LATestRecorder : NSObject
@property(nonatomic, assign) NSInteger caseCount;
@property(nonatomic, assign) NSInteger passCount;
@property(nonatomic, assign) NSInteger failureCount;
@property(nonatomic, assign) NSInteger skipCount;
@property(nonatomic, copy) NSString *suiteName;
@property(nonatomic, strong) NSMutableArray *suites;
@property(nonatomic, strong) NSMutableArray *failures;
@property(nonatomic, strong) NSMutableArray *skipped;
@end

@interface LATestCountingPersistence : LAActivatorPersistence
@property(nonatomic, assign) NSInteger saveCount;
@property(nonatomic, copy) NSDictionary *lastSavedDictionary;
@end

@implementation LATestRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _suites = [NSMutableArray array];
        _failures = [NSMutableArray array];
        _skipped = [NSMutableArray array];
    }
    return self;
}

- (void)beginSuite:(NSString *)suiteName {
    self.suiteName = suiteName ?: @"Unknown";
    [self.suites addObject:self.suiteName];
}

- (void)pass:(NSString *)caseName {
    self.caseCount += 1;
    self.passCount += 1;
}

- (void)fail:(NSString *)caseName reason:(NSString *)reason {
    self.caseCount += 1;
    self.failureCount += 1;
    [self.failures addObject:[NSString stringWithFormat:@"%@/%@: %@", self.suiteName ?: @"Unknown",
                                                        caseName ?: @"Unknown", reason ?: @"Failed"]];
}

- (void)skip:(NSString *)caseName reason:(NSString *)reason {
    self.caseCount += 1;
    self.skipCount += 1;
    [self.skipped addObject:[NSString stringWithFormat:@"%@/%@: %@", self.suiteName ?: @"Unknown",
                                                       caseName ?: @"Unknown", reason ?: @"Skipped"]];
}

- (void)expect:(BOOL)condition caseName:(NSString *)caseName reason:(NSString *)reason {
    if (condition) {
        [self pass:caseName];
    } else {
        [self fail:caseName reason:reason];
    }
}

- (NSDictionary *)resultDictionary {
    return @{
        LAActivatorIPCKeyTestingSuites : self.suites,
        LAActivatorIPCKeyTestingFailures : self.failures,
        LAActivatorIPCKeyTestingSkipped : self.skipped,
        LAActivatorIPCKeyTestingCaseCount : @(self.caseCount),
        LAActivatorIPCKeyTestingPassCount : @(self.passCount),
        LAActivatorIPCKeyTestingFailureCount : @(self.failureCount),
        LAActivatorIPCKeyTestingSkipCount : @(self.skipCount),
    };
}

@end

@interface LATestTouch : UITouch
@property(nonatomic, assign) UITouchPhase testPhase;
@end

@implementation LATestTouch
- (UITouchPhase)phase {
    return self.testPhase;
}
@end

@interface LATestTouchEvent : UIEvent
@property(nonatomic, copy) NSSet *testTouches;
@end

@implementation LATestTouchEvent
- (UIEventType)type {
    return UIEventTypeTouches;
}

- (NSSet *)allTouches {
    return self.testTouches ?: [NSSet set];
}
@end

@interface LATestEventDataSource : NSObject <LAEventDataSource>
@property(nonatomic, assign) BOOL hidden;
@property(nonatomic, assign) BOOL requiresAssignment;
@property(nonatomic, assign) BOOL supportsRemoval;
@property(nonatomic, assign) BOOL supportsUnlockingDeviceToSend;
@property(nonatomic, assign) NSUInteger removalCount;
@property(nonatomic, copy) NSArray *compatibleModes;
@end

@implementation LATestCountingPersistence

- (BOOL)saveDictionary:(NSDictionary *)dictionary {
    self.saveCount += 1;
    self.lastSavedDictionary = dictionary;
    return YES;
}

@end

@implementation LATestEventDataSource

- (instancetype)init {
    self = [super init];
    if (self) {
        _requiresAssignment = YES;
        _compatibleModes = @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
    }
    return self;
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
    return [NSString stringWithFormat:@"Title %@", eventName ?: @""];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
    return @"Testing";
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
    return [NSString stringWithFormat:@"Description %@", eventName ?: @""];
}

- (BOOL)eventWithNameIsHidden:(NSString *)eventName {
    return self.hidden;
}

- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName {
    return self.requiresAssignment;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
    return eventMode.length == 0 || [self.compatibleModes containsObject:eventMode];
}

- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
    return self.supportsUnlockingDeviceToSend;
}

- (BOOL)eventWithNameSupportsRemoval:(NSString *)eventName {
    return self.supportsRemoval;
}

- (void)removeEventWithName:(NSString *)eventName {
    self.removalCount += 1;
}

@end

@interface LATestListener : NSObject <LAListener>
@property(nonatomic, assign) NSInteger receiveCount;
@property(nonatomic, assign) NSInteger abortCount;
@property(nonatomic, assign) NSInteger previewCount;
@property(nonatomic, assign) NSInteger deactivateCount;
@property(nonatomic, assign) NSInteger otherHandledCount;
@property(nonatomic, assign) NSInteger modeChangeCount;
@property(nonatomic, assign) NSInteger unlockingCount;
@property(nonatomic, assign) BOOL handlesReceivedEvents;
@property(nonatomic, assign) BOOL requiresNoTouchEvents;
@property(nonatomic, assign) BOOL supportsRemoval;
@property(nonatomic, assign) NSUInteger removalRequestCount;
@property(nonatomic, assign) NSUInteger smallIconRequestCount;
@property(nonatomic, assign) NSUInteger localizedTitleRequestCount;
@property(nonatomic, assign) NSUInteger localizedGroupRequestCount;
@property(nonatomic, assign) NSUInteger localizedDescriptionRequestCount;
@property(nonatomic, copy) NSArray *compatibleModes;
@property(nonatomic, copy) NSArray *exclusiveGroups;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedGroup;
@property(nonatomic, copy) NSString *localizedDescription;
@property(nonatomic, copy) NSString *lastReceivedEventMode;
@property(nonatomic, copy) NSDictionary *lastReceivedUserInfo;
@property(nonatomic, strong) UIImage *smallIconImage;
@end

@implementation LATestListener

- (instancetype)init {
    self = [super init];
    if (self) {
        _compatibleModes = @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
        _exclusiveGroups = @[];
    }
    return self;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    self.receiveCount += 1;
    self.lastReceivedEventMode = event.mode;
    self.lastReceivedUserInfo = event.userInfo;
    if (self.handlesReceivedEvents) {
        event.handled = YES;
    }
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    self.abortCount += 1;
}

- (void)activator:(LAActivator *)activator receivePreviewEventForListenerName:(NSString *)listenerName {
    self.previewCount += 1;
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event {
    self.deactivateCount += 1;
    event.handled = YES;
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event {
    self.otherHandledCount += 1;
}

- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode {
    self.modeChangeCount += 1;
}

- (BOOL)activator:(LAActivator *)activator
    receiveUnlockingDeviceEvent:(LAEvent *)event
                forListenerName:(NSString *)listenerName {
    self.unlockingCount += 1;
    event.handled = YES;
    return YES;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName {
    return self.compatibleModes;
}

- (NSArray *)activator:(LAActivator *)activator
    requiresExclusiveAssignmentGroupsForListenerName:(NSString *)listenerName {
    return self.exclusiveGroups;
}

- (id)activator:(LAActivator *)activator
    requiresInfoDictionaryValueOfKey:(NSString *)key
                 forListenerWithName:(NSString *)listenerName {
    if ([key isEqualToString:@"requires-no-touch-events"]) {
        return @(self.requiresNoTouchEvents);
    }
    return nil;
}

- (BOOL)activator:(LAActivator *)activator requiresSupportsRemovalForListenerWithName:(NSString *)listenerName {
    return self.supportsRemoval;
}

- (void)activator:(LAActivator *)activator requestsRemovalForListenerWithName:(NSString *)listenerName {
    self.removalRequestCount += 1;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName {
    self.localizedTitleRequestCount += 1;
    return self.localizedTitle;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName {
    self.localizedGroupRequestCount += 1;
    return self.localizedGroup;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName {
    self.localizedDescriptionRequestCount += 1;
    return self.localizedDescription;
}

- (UIImage *)activator:(LAActivator *)activator
    requiresSmallIconForListenerName:(NSString *)listenerName
                               scale:(CGFloat)scale {
    self.smallIconRequestCount += 1;
    return self.smallIconImage;
}

@end

@interface LATestSimpleAbortListener : NSObject <LAListener>
@property(nonatomic, assign) NSInteger abortCount;
@end

@implementation LATestSimpleAbortListener
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event {
    self.abortCount += 1;
}
@end

@interface NSObject (LATestURLActionListenerTesting)
+ (void)setTestingOpenHandler:(BOOL (^)(NSURL *url, NSString *listenerName))handler;
+ (void)setTestingURLMetadata:(NSDictionary *)metadata forListenerName:(NSString *)listenerName;
+ (NSURL *)testingLastOpenedURL;
+ (NSString *)testingLastOpenedListenerName;
+ (void)resetTestingState;
@end

@interface LAActivatorTestSupport ()
+ (NSDictionary *)okReplyWithValue:(id)value;
+ (NSDictionary *)failureReply;
+ (void)removeTestPlist;
+ (NSDictionary *)runStableTestsWithActivator:(LAActivator *)activator;
+ (NSDictionary *)runRuntimeInputTestsWithActivator:(LAActivator *)activator;
+ (NSDictionary *)runDeviceRuntimeTestsWithActivator:(LAActivator *)activator;
+ (void)runEventTestsWithRecorder:(LATestRecorder *)recorder;
+ (void)runPersistenceTestsWithRecorder:(LATestRecorder *)recorder;
+ (void)runResourceTestsWithRecorder:(LATestRecorder *)recorder;
+ (void)runTouchActivityTestsWithRecorder:(LATestRecorder *)recorder;
+ (void)runSpringBoardCoreTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runDispatchTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runBuiltInActionRegistryTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runBuiltInURLActionTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runRuntimeInputTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)runRuntimeDeviceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
+ (void)cleanActivator:(LAActivator *)activator;
+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator;
+ (void)sendSyntheticTouchWithTouching:(BOOL)touching;
+ (void)waitForSyntheticTouchDelivery;
+ (BOOL)resetHomeScreen;
+ (BOOL)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier;
+ (BOOL)prepareApplicationModeWithBundleIdentifier:(NSString *)bundleIdentifier
                                         activator:(LAActivator *)activator
                                          attempts:(NSUInteger)attempts;
+ (BOOL)suspendApplication;
+ (BOOL)lockDevice;
+ (BOOL)unlockDeviceWithPasscode:(NSString *)passcode;
+ (BOOL)isDeviceLocked;
+ (NSString *)frontMostDisplayIdentifier;
+ (BOOL)waitForFrontMostApplicationWithBundleIdentifier:(NSString *)bundleIdentifier timeout:(NSTimeInterval)timeout;
+ (NSString *)runtimeDebugReasonWithPrefix:(NSString *)prefix activator:(LAActivator *)activator;
+ (void)performOnMainThreadSynchronously:(dispatch_block_t)block;
+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval;
+ (void)waitForMainQueue;
@end

@implementation LAActivatorTestSupport

+ (NSString *)userInfoProbeEventName {
    return @"libactivator.test.client-facade.user-info";
}

+ (NSString *)userInfoProbeListenerName {
    return @"libactivator.test.client-facade.user-info";
}

+ (NSDictionary *)handleCommandWithUserInfo:(NSDictionary *)userInfo activator:(LAActivator *)activator {
    NSString *command = [userInfo[LAActivatorIPCKeyTestingCommand] isKindOfClass:NSString.class]
                            ? userInfo[LAActivatorIPCKeyTestingCommand]
                            : nil;
    if ([command isEqualToString:LAActivatorIPCTestingCommandPing]) {
        return [self okReplyWithValue:@"ready"];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandCleanup]) {
        [self cleanActivator:activator];
        [self removeTestPlist];
        return [self okReplyWithValue:@"clean"];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRun]) {
        return [self okReplyWithValue:[self runStableTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRunRuntimeInput]) {
        return [self okReplyWithValue:[self runRuntimeInputTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRunDeviceRuntime]) {
        return [self okReplyWithValue:[self runDeviceRuntimeTestsWithActivator:activator]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandRuntimeState]) {
        return [self okReplyWithValue:[activator la_runtimeStateDebugDictionary]];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandPrepareUserInfoProbe]) {
        NSString *eventName = [self userInfoProbeEventName];
        NSString *listenerName = [self userInfoProbeListenerName];
        LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
        LATestListener *listener = [[LATestListener alloc] init];
        listener.handlesReceivedEvents = YES;
        [activator registerEventDataSource:dataSource forEventName:eventName];
        [activator registerListener:listener forName:listenerName];
        return [self okReplyWithValue:@{
            LAActivatorIPCKeyEventName : eventName,
            LAActivatorIPCKeyListenerName : listenerName,
        }];
    }
    if ([command isEqualToString:LAActivatorIPCTestingCommandUserInfoProbeResult]) {
        id<LAListener> listener = [activator listenerForName:[self userInfoProbeListenerName]];
        if (![listener isKindOfClass:LATestListener.class]) {
            return [self failureReply];
        }
        LATestListener *testListener = (LATestListener *)listener;
        return [self okReplyWithValue:@{
            @"ReceiveCount" : @(testListener.receiveCount),
            @"UserInfo" : testListener.lastReceivedUserInfo ?: @{},
        }];
    }
    return [self failureReply];
}

#pragma mark - Replies

+ (NSDictionary *)okReplyWithValue:(id)value {
    if (value) {
        return @{LAActivatorIPCKeyOK : @YES, LAActivatorIPCKeyValue : value};
    }
    return @{LAActivatorIPCKeyOK : @YES};
}

+ (NSDictionary *)failureReply {
    return @{LAActivatorIPCKeyOK : @NO};
}

#pragma mark - Test Suites

+ (NSDictionary *)runStableTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [self cleanActivator:activator];
    [self removeTestPlist];
    [self runEventTestsWithRecorder:recorder];
    [self runPersistenceTestsWithRecorder:recorder];
    [self runResourceTestsWithRecorder:recorder];
    [self runTouchActivityTestsWithRecorder:recorder];
    [self runSpringBoardCoreTestsWithRecorder:recorder activator:activator];
    [self runDispatchTestsWithRecorder:recorder activator:activator];
    [self runBuiltInActionRegistryTestsWithRecorder:recorder activator:activator];
    [self runBuiltInURLActionTestsWithRecorder:recorder activator:activator];
    [self cleanActivator:activator];
    return [recorder resultDictionary];
}

+ (NSDictionary *)runRuntimeInputTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [self cleanActivator:activator];
    [self cleanRuntimeInputStateWithActivator:activator];
    [self runRuntimeInputTestsWithRecorder:recorder activator:activator];
    [self cleanRuntimeInputStateWithActivator:activator];
    [self cleanActivator:activator];
    return [recorder resultDictionary];
}

+ (NSDictionary *)runDeviceRuntimeTestsWithActivator:(LAActivator *)activator {
    LATestRecorder *recorder = [[LATestRecorder alloc] init];
    [self cleanActivator:activator];
    [self runRuntimeDeviceTestsWithRecorder:recorder activator:activator];
    [self cleanActivator:activator];
    return [recorder resultDictionary];
}

+ (void)runEventTestsWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"LAEvent"];

    LAEvent *event = [LAEvent eventWithName:@"libactivator.test.event" mode:nil];
    event.handled = YES;
    event.userInfo = @{@"Key" : @"Value"};
    [recorder expect:[event.name isEqualToString:@"libactivator.test.event"]
            caseName:@"factory-name"
              reason:@"Name mismatch"];
    [recorder expect:event.mode == nil caseName:@"nil-mode" reason:@"Nil mode was not preserved"];
    [recorder expect:event.handled caseName:@"handled" reason:@"Handled flag mismatch"];
    [recorder expect:[event.userInfo[@"Key"] isEqualToString:@"Value"]
            caseName:@"user-info"
              reason:@"User info mismatch"];

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:NO error:&archiveError];
    NSError *unarchiveError = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&unarchiveError];
    unarchiver.requiresSecureCoding = NO;
    LAEvent *decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    [recorder expect:data.length > 0 && archiveError == nil && unarchiveError == nil &&
                     [decoded.name isEqualToString:event.name] && decoded.handled
            caseName:@"nscoding"
              reason:@"NSCoding round-trip failed"];
}

+ (void)runPersistenceTestsWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"Persistence"];

    NSString *path = jbroot(@"/var/mobile/Library/Preferences/libactivator.tests.plist");
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    LAActivatorPersistence *persistence = [[LAActivatorPersistence alloc] initWithFilePath:path];
    [recorder expect:[persistence loadDictionary] == nil
            caseName:@"default-empty"
              reason:@"Missing test plist should load nil"];

    NSDictionary *dictionary = @{@"SchemaVersion" : @1, @"Value" : @"Testing"};
    [recorder expect:[persistence saveDictionary:dictionary] caseName:@"save" reason:@"Could not save test plist"];
    [recorder expect:[[persistence loadDictionary][@"Value"] isEqualToString:@"Testing"]
            caseName:@"load"
              reason:@"Saved value did not round-trip"];

    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    NSUInteger permissions = [attributes[NSFilePosixPermissions] unsignedIntegerValue] & 0777;
    NSString *protection = attributes[NSFileProtectionKey];
    [recorder expect:permissions == (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
            caseName:@"permissions"
              reason:@"Saved plist permissions were not 0666"];
    [recorder expect:protection == nil || [protection isEqualToString:NSFileProtectionNone]
            caseName:@"file-protection"
              reason:@"Saved plist should not use protected file access"];

    [@"invalid" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [recorder expect:[persistence loadDictionary] == nil
            caseName:@"invalid-ignored"
              reason:@"Invalid plist should be ignored"];

    LATestCountingPersistence *countingPersistence =
        [[LATestCountingPersistence alloc] initWithFilePath:@"libactivator-counting-tests.plist"];
    LAActivatorBackend *backend = [[LAActivatorBackend alloc] initWithPersistence:countingPersistence];
    LAEvent *event = [LAEvent eventWithName:@"libactivator.test.persistence" mode:LAEventModeSpringBoard];
    [backend setCurrentProfileNameIfChanged:@"Testing"];
    [backend assignEvent:event toListenersWithNames:@[ @"libactivator.test.listener.one" ]];
    [backend setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
    [recorder expect:[[backend assignedListenerNamesForEvent:event]
                         isEqualToArray:@[ @"libactivator.test.listener.one" ]] &&
                     [backend applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"] &&
                     [backend.currentProfileName isEqualToString:@"Testing"]
            caseName:@"coalesced-in-memory"
              reason:@"Backend state was not updated before persistence flush"];
    [recorder expect:countingPersistence.saveCount == 0
            caseName:@"coalesced-not-immediate"
              reason:@"Backend should not write immediately for every mutation"];
    [recorder expect:[backend flushPendingPersistentState] && countingPersistence.saveCount == 1
            caseName:@"coalesced-flush"
              reason:@"Pending backend changes were not coalesced into one save"];
    NSDictionary *savedProfiles = countingPersistence.lastSavedDictionary[@"Profiles"];
    [recorder expect:[countingPersistence.lastSavedDictionary[@"CurrentProfileName"] isEqualToString:@"Testing"] &&
                     [savedProfiles isKindOfClass:NSDictionary.class] &&
                     [countingPersistence.lastSavedDictionary[@"BlacklistedDisplayIdentifiers"]
                         containsObject:@"com.apple.Preferences"]
            caseName:@"coalesced-snapshot"
              reason:@"Coalesced save did not contain the latest backend state"];
    [backend setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [recorder expect:countingPersistence.saveCount == 1 &&
                     ![backend applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"coalesced-next-dirty"
              reason:@"Second mutation should update memory before the next flush"];
    [recorder expect:[backend flushPendingPersistentState] && countingPersistence.saveCount == 2
            caseName:@"coalesced-next-flush"
              reason:@"Second dirty pass did not schedule a new save"];

    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

+ (void)runResourceTestsWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"Resources"];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    LAActivatorResourceManager *resourceManager = LAActivatorResourceManager.sharedManager;

    NSString *eventName = @"libactivator.test.resource.capability";
    NSString *eventPath = [[resourceManager eventsDirectoryPath] stringByAppendingPathComponent:eventName];
    [fileManager removeItemAtPath:eventPath error:nil];
    [fileManager createDirectoryAtPath:eventPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *eventInfo = @{
        @"title" : @"Unsupported Test Event",
        @"group" : @"Testing",
        @"required-capabilities" : @[ @"libactivator.test.missing-capability" ],
    };
    [eventInfo writeToFile:[eventPath stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
    [recorder expect:![resourceManager.availableEventNames containsObject:eventName] &&
                     [resourceManager eventInfoDictionaryForName:eventName] == nil
            caseName:@"required-capability-filter"
              reason:@"Unsupported resource capability should hide event metadata"];

    [fileManager removeItemAtPath:eventPath error:nil];

    NSArray *smallIcons = [resourceManager infoDictionaryValueOfKey:@"small-icons"
                                                    forListenerName:@"libactivator.settings.wifi"];
    [recorder expect:[smallIcons isKindOfClass:NSArray.class] && smallIcons.count > 0
            caseName:@"small-icons-metadata"
              reason:@"1.9.13 bundled listener small icon metadata was not read"];

    NSString *resourceRootPath = @"/var/mobile/Library/Caches/libactivator-resource-path-test.dat";
    NSString *resourcePath = jbroot(resourceRootPath);
    NSData *resourceData = [@"libactivator-resource-path-test" dataUsingEncoding:NSUTF8StringEncoding];
    [resourceData writeToFile:resourcePath atomically:YES];
    NSString *resolvedPath = [resourceManager resolvedPathForResourcePath:resourceRootPath];
    NSData *resolvedData = resolvedPath.length > 0 ? [NSData dataWithContentsOfFile:resolvedPath] : nil;
    [recorder expect:[resolvedPath isEqualToString:resourcePath] && [resolvedData isEqualToData:resourceData]
            caseName:@"absolute-path-resolution"
              reason:@"Absolute resource path did not resolve through jbroot before the original path"];

    [fileManager removeItemAtPath:resourcePath error:nil];
}

+ (void)runTouchActivityTestsWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"TouchActivity"];

    LATouchActivityTracker *tracker = [[LATouchActivityTracker alloc] init];
    __block NSInteger immediateCount = 0;
    [tracker performWhenTouchesEnd:^{
        immediateCount += 1;
    }];
    [self waitForMainQueue];
    [recorder expect:immediateCount == 1
            caseName:@"inactive-runs-immediately"
              reason:@"Inactive touch tracker did not run pending work immediately"];

    LATestTouch *touch = [[LATestTouch alloc] init];
    LATestTouchEvent *event = [[LATestTouchEvent alloc] init];
    event.testTouches = [NSSet setWithObject:touch];

    touch.testPhase = UITouchPhaseBegan;
    [tracker noteTouchEvent:event];
    [recorder expect:tracker.touchActive
            caseName:@"touch-began-active"
              reason:@"Touch began did not mark tracker active"];

    __block NSInteger pendingCount = 0;
    [tracker performWhenTouchesEnd:^{
        pendingCount += 1;
    }];
    [tracker performWhenTouchesEnd:^{
        pendingCount += 1;
    }];
    [self waitForMainQueue];
    [recorder expect:pendingCount == 0
            caseName:@"active-defers-blocks"
              reason:@"Active touch tracker ran pending work before touches ended"];

    touch.testPhase = UITouchPhaseEnded;
    [tracker noteTouchEvent:event];
    [self waitForMainQueue];
    [recorder expect:!tracker.touchActive && pendingCount == 2
            caseName:@"touch-ended-drains-blocks"
              reason:@"Touch ended did not drain all pending work"];

    LATouchActivityTracker *cancelTracker = [[LATouchActivityTracker alloc] init];
    LATestTouch *cancelledTouch = [[LATestTouch alloc] init];
    LATestTouchEvent *cancelEvent = [[LATestTouchEvent alloc] init];
    cancelEvent.testTouches = [NSSet setWithObject:cancelledTouch];
    cancelledTouch.testPhase = UITouchPhaseBegan;
    [cancelTracker noteTouchEvent:cancelEvent];
    __block NSInteger cancelCount = 0;
    [cancelTracker performWhenTouchesEnd:^{
        cancelCount += 1;
    }];
    cancelledTouch.testPhase = UITouchPhaseCancelled;
    [cancelTracker noteTouchEvent:cancelEvent];
    [self waitForMainQueue];
    [recorder expect:!cancelTracker.touchActive && cancelCount == 1
            caseName:@"touch-cancel-drains-blocks"
              reason:@"Touch cancellation did not drain pending work"];
}

+ (void)runSpringBoardCoreTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"SpringBoardCore"];

    NSString *eventName = @"libactivator.test.core";
    NSString *listenerAName = @"libactivator.test.listener.a";
    NSString *listenerBName = @"libactivator.test.listener.b";
    NSString *listenerCName = @"libactivator.test.listener.c";
    NSString *unseenListenerName = @"libactivator.test.listener.unseen";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *listenerA = [[LATestListener alloc] init];
    LATestListener *listenerB = [[LATestListener alloc] init];
    LATestListener *listenerC = [[LATestListener alloc] init];
    LATestListener *unseenListener = [[LATestListener alloc] init];
    listenerA.exclusiveGroups = @[ @"exclusive" ];
    listenerB.exclusiveGroups = @[ @"exclusive" ];
    listenerC.compatibleModes = @[ LAEventModeSpringBoard ];

    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:listenerA forName:listenerAName];
    [activator registerListener:listenerB forName:listenerBName];
    [activator registerListener:listenerC forName:listenerCName];
    [activator registerListener:unseenListener forName:unseenListenerName ignoreHasSeen:YES];

    [recorder expect:[activator hasEventWithName:eventName]
            caseName:@"event-registry"
              reason:@"Event was not registered"];
    [recorder expect:[activator hasEventWithName:LAEventNameVolumeMuteOn] &&
                     [activator hasEventWithName:LAEventNameVolumeDownPressWithMenu] &&
                     [activator hasEventWithName:LAEventNameStatusBarTapSingle]
            caseName:@"bundled-event-registry"
              reason:@"1.9.13 bundled event metadata was not registered"];
    [recorder expect:[activator eventWithNameSupportsUnlockingDeviceToSend:LAEventNameFingerprintSensorHold] == NO
            caseName:@"bundled-event-unlock-metadata"
              reason:@"1.9.13 unlock-to-send metadata was not read from bundled events"];
    [recorder expect:[activator assignmentWarningForEventWithName:LAEventNameVolumeMuteOn] == nil
            caseName:@"bundled-event-assignment-warning-fallback"
              reason:@"Missing assignment warning metadata should return nil"];
    id<LAEventDataSource> statusBarDataSource = [activator eventDataSourceForEventName:LAEventNameStatusBarTapSingle];
    BOOL statusBarIsUnprotected = statusBarDataSource &&
                                  [statusBarDataSource respondsToSelector:@selector(eventWithNameIsUnprotected:)] &&
                                  [statusBarDataSource eventWithNameIsUnprotected:LAEventNameStatusBarTapSingle];
    [recorder expect:statusBarIsUnprotected
            caseName:@"bundled-event-unprotected-metadata"
              reason:@"1.9.13 unprotected event metadata was not exposed through the data source"];
    [recorder expect:[activator listenerWithNameNeedsPoweredDisplay:@"libactivator.audio.launch-playing-app"]
            caseName:@"bundled-listener-powered-display-metadata"
              reason:@"1.9.13 listener needs-powered-display metadata was not used as fallback"];
    [recorder expect:[[activator exclusiveAssignmentGroupsForListenerName:@"libactivator.audio.decrease-volume"]
                         isEqualToArray:@[ @"volume-change" ]]
            caseName:@"bundled-listener-exclusive-group-metadata"
              reason:@"1.9.13 listener exclusive assignment group metadata was not used as fallback"];
    NSString *removableEventName = @"libactivator.test.removable-event";
    NSString *nonremovableEventName = @"libactivator.test.nonremovable-event";
    LATestEventDataSource *removableDataSource = [[LATestEventDataSource alloc] init];
    LATestEventDataSource *nonremovableDataSource = [[LATestEventDataSource alloc] init];
    removableDataSource.supportsRemoval = YES;
    [activator registerEventDataSource:removableDataSource forEventName:removableEventName];
    [activator registerEventDataSource:nonremovableDataSource forEventName:nonremovableEventName];
    [activator removeEventWithName:nonremovableEventName];
    [recorder expect:nonremovableDataSource.removalCount == 0 &&
                     [activator eventDataSourceForEventName:nonremovableEventName] == nonremovableDataSource
            caseName:@"event-removal-requires-support"
              reason:@"Event removal ignored supports-removal metadata"];
    [activator removeEventWithName:removableEventName];
    [recorder expect:removableDataSource.removalCount == 1 && ![activator hasEventWithName:removableEventName]
            caseName:@"event-removal-supported"
              reason:@"Supported event removal did not remove the event data source"];
    [activator unregisterEventDataSourceWithEventName:nonremovableEventName];
    __block NSUInteger eventNotificationCount = 0;
    id eventObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableEventsChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        eventNotificationCount += 1;
                                                    }];
    LATestEventDataSource *replacementDataSource = [[LATestEventDataSource alloc] init];
    [activator registerEventDataSource:replacementDataSource forEventName:eventName];
    [recorder expect:[activator eventDataSourceForEventName:eventName] == replacementDataSource &&
                     eventNotificationCount == 0
            caseName:@"event-data-source-overwrite-no-availability-notification"
              reason:@"Event data source overwrite changed availability notification state"];
    [activator registerEventDataSource:[[LATestEventDataSource alloc] init]
                          forEventName:@"libactivator.test.new-event-data-source"];
    [recorder expect:eventNotificationCount == 1
            caseName:@"new-event-data-source-availability-notification"
              reason:@"New event data source registration did not post availability notification"];
    [NSNotificationCenter.defaultCenter removeObserver:eventObserver];
    [recorder expect:[activator hasListenerWithName:listenerAName]
            caseName:@"listener-registry"
              reason:@"Listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:listenerAName]
            caseName:@"seen-listener"
              reason:@"Seen listener was not recorded"];
    [recorder expect:[activator hasListenerWithName:unseenListenerName] &&
                     ![activator hasSeenListenerWithName:unseenListenerName]
            caseName:@"unseen-listener-registration"
              reason:@"ignoreHasSeen listener registration was not preserved"];
    NSString *localizationListenerName = @"libactivator.test.listener.localization";
    LATestListener *localizationListener = [[LATestListener alloc] init];
    localizationListener.localizedTitle = @"Cached Title";
    localizationListener.localizedGroup = @"Cached Group";
    localizationListener.localizedDescription = @"Cached Description";
    [activator registerListener:localizationListener forName:localizationListenerName];
    NSString *firstLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    NSString *firstLocalizedGroup = [activator localizedGroupForListenerName:localizationListenerName];
    NSString *firstLocalizedDescription = [activator localizedDescriptionForListenerName:localizationListenerName];
    localizationListener.localizedTitle = @"Changed Title";
    localizationListener.localizedGroup = @"Changed Group";
    localizationListener.localizedDescription = @"Changed Description";
    NSString *secondLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    NSString *secondLocalizedGroup = [activator localizedGroupForListenerName:localizationListenerName];
    NSString *secondLocalizedDescription = [activator localizedDescriptionForListenerName:localizationListenerName];
    [recorder expect:[firstLocalizedTitle isEqualToString:@"Cached Title"] &&
                     [secondLocalizedTitle isEqualToString:firstLocalizedTitle] &&
                     [firstLocalizedGroup isEqualToString:@"Cached Group"] &&
                     [secondLocalizedGroup isEqualToString:firstLocalizedGroup] &&
                     [firstLocalizedDescription isEqualToString:@"Cached Description"] &&
                     [secondLocalizedDescription isEqualToString:firstLocalizedDescription] &&
                     localizationListener.localizedTitleRequestCount == 1 &&
                     localizationListener.localizedGroupRequestCount == 1 &&
                     localizationListener.localizedDescriptionRequestCount == 1
            caseName:@"listener-localization-cache"
              reason:@"Listener localization lookup did not use the metadata cache"];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
                                                      object:UIApplication.sharedApplication];
    NSString *thirdLocalizedTitle = [activator localizedTitleForListenerName:localizationListenerName];
    [recorder expect:[thirdLocalizedTitle isEqualToString:@"Changed Title"] &&
                     localizationListener.localizedTitleRequestCount == 2
            caseName:@"listener-cache-cleared-by-memory-warning"
              reason:@"Listener metadata cache was not cleared by memory warning"];
    LATestListener *replacementLocalizationListener = [[LATestListener alloc] init];
    replacementLocalizationListener.localizedTitle = @"Replacement Title";
    [activator registerListener:replacementLocalizationListener forName:localizationListenerName];
    [recorder expect:[[activator localizedTitleForListenerName:localizationListenerName]
                         isEqualToString:@"Replacement Title"] &&
                     replacementLocalizationListener.localizedTitleRequestCount == 1
            caseName:@"listener-localization-cache-invalidated-by-registration"
              reason:@"Listener localization cache was not invalidated by listener registration"];
    NSString *iconListenerName = @"libactivator.test.listener.icon";
    LATestListener *iconListener = [[LATestListener alloc] init];
    iconListener.smallIconImage = [[UIImage alloc] init];
    [activator registerListener:iconListener forName:iconListenerName];
    UIImage *firstSmallIcon = [activator smallIconForListenerName:iconListenerName];
    iconListener.smallIconImage = nil;
    UIImage *secondSmallIcon = [activator smallIconForListenerName:iconListenerName];
    [recorder expect:firstSmallIcon && firstSmallIcon == secondSmallIcon && iconListener.smallIconRequestCount == 1
            caseName:@"small-icon-cache"
              reason:@"Small listener icon lookup did not use the cache"];
    LATestListener *replacementIconListener = [[LATestListener alloc] init];
    replacementIconListener.smallIconImage = [[UIImage alloc] init];
    [activator registerListener:replacementIconListener forName:iconListenerName];
    UIImage *replacementSmallIcon = [activator smallIconForListenerName:iconListenerName];
    [recorder expect:replacementSmallIcon == replacementIconListener.smallIconImage &&
                     replacementIconListener.smallIconRequestCount == 1
            caseName:@"small-icon-cache-invalidated-by-registration"
              reason:@"Small listener icon cache was not invalidated by listener registration"];
    [recorder expect:[activator smallIconForListenerName:@"com.apple.Preferences"] == nil
            caseName:@"small-icon-no-global-application-fallback"
              reason:@"Core small icon lookup used a global application icon fallback"];
    [activator requestRemovalForListenerWithName:listenerAName];
    [recorder expect:listenerA.removalRequestCount == 0
            caseName:@"listener-removal-request-requires-support"
              reason:@"Listener removal request ignored supports-removal metadata"];
    listenerA.supportsRemoval = YES;
    [activator requestRemovalForListenerWithName:listenerAName];
    [recorder expect:listenerA.removalRequestCount == 1
            caseName:@"listener-removal-request-supported"
              reason:@"Supported listener removal request was not delivered"];
    __block NSUInteger listenerNotificationCount = 0;
    id listenerObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:LAActivatorAvailableListenersChangedNotification
                                                        object:activator
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *notification) {
                                                        listenerNotificationCount += 1;
                                                    }];
    LATestListener *replacementListener = [[LATestListener alloc] init];
    replacementListener.exclusiveGroups = @[ @"exclusive" ];
    [activator registerListener:replacementListener forName:listenerAName];
    [recorder expect:[activator listenerForName:listenerAName] == replacementListener && listenerNotificationCount == 0
            caseName:@"listener-overwrite-no-availability-notification"
              reason:@"Listener overwrite changed availability notification state"];
    [activator registerListener:replacementListener forName:@"libactivator.test.listener.new"];
    [recorder expect:listenerNotificationCount == 1
            caseName:@"new-listener-availability-notification"
              reason:@"New listener registration did not post availability notification"];
    [NSNotificationCenter.defaultCenter removeObserver:listenerObserver];
    [recorder expect:![activator listenerNamesAreMutuallyCompatible:@[ listenerAName, listenerBName ]]
            caseName:@"exclusive-groups"
              reason:@"Exclusive listeners were reported compatible"];

    LAEvent *springboardEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:springboardEvent toListenersWithNames:@[ listenerBName, listenerAName ]];
    NSArray *assignedNames = [activator assignedListenerNamesForEvent:springboardEvent];
    [recorder expect:[assignedNames isEqualToArray:@[ listenerAName, listenerBName ]]
            caseName:@"assignment-normalization"
              reason:@"Assignment names were not normalized"];
    [recorder expect:[activator eventsAssignedToListenerWithName:listenerAName].count == 1
            caseName:@"reverse-assignment"
              reason:@"Reverse assignment lookup failed"];

    LAEvent *applicationEvent = [LAEvent eventWithName:eventName mode:LAEventModeApplication];
    [activator assignEvent:applicationEvent toListenerWithName:listenerCName];
    [recorder expect:[activator assignedListenerNamesForEvent:applicationEvent].count == 0
            caseName:@"assignment-compatibility-filter"
              reason:@"Incompatible assignment was returned as active"];
    [recorder
          expect:[activator eventsAssignedToListenerWithName:listenerCName].count == 1
        caseName:@"reverse-assignment-keeps-incompatible"
          reason:@"Reverse assignment should include available events assigned to currently incompatible listeners"];
    [activator addListenerAssignment:listenerAName toEvent:applicationEvent];
    [activator removeListenerAssignment:listenerAName fromEvent:applicationEvent];
    [recorder expect:[activator assignedListenerNamesForEvent:applicationEvent].count == 0 &&
                     [activator eventsAssignedToListenerWithName:listenerCName].count == 1
            caseName:@"incremental-assignment-keeps-incompatible"
              reason:@"Incremental assignment rewrite dropped an incompatible stored assignment"];
    [activator unregisterEventDataSourceWithEventName:eventName];
    [recorder expect:[activator eventsAssignedToListenerWithName:listenerCName].count == 0
            caseName:@"reverse-assignment-hides-unavailable-event"
              reason:@"Reverse assignment exposed an unavailable event"];
    [activator registerEventDataSource:dataSource forEventName:eventName];

    [activator setCurrentProfileName:@"Testing"];
    [recorder expect:[[activator availableProfileNames] containsObject:@"Testing"]
            caseName:@"profile-create"
              reason:@"Profile was not created"];
    [recorder expect:[activator assignedListenerNamesForEvent:springboardEvent].count == 0
            caseName:@"profile-isolation"
              reason:@"Assignments leaked across profiles"];
    [activator setCurrentProfileName:@"Default"];

    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
    [recorder expect:[activator applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"blacklist-set"
              reason:@"Blacklist set failed"];
    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [recorder expect:![activator applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"blacklist-clear"
              reason:@"Blacklist clear failed"];
}

+ (void)runDispatchTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"Dispatch"];

    NSString *eventName = @"libactivator.test.dispatch";
    NSString *listenerAName = @"libactivator.test.dispatch.a";
    NSString *listenerBName = @"libactivator.test.dispatch.b";
    NSString *sharedListenerFirstName = @"libactivator.test.dispatch.shared.first";
    NSString *sharedListenerSecondName = @"libactivator.test.dispatch.shared.second";
    NSString *simpleAbortName = @"libactivator.test.dispatch.simple-abort";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *listenerA = [[LATestListener alloc] init];
    LATestListener *listenerB = [[LATestListener alloc] init];
    LATestListener *sharedListener = [[LATestListener alloc] init];
    LATestSimpleAbortListener *simpleAbort = [[LATestSimpleAbortListener alloc] init];
    listenerA.handlesReceivedEvents = YES;

    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:listenerA forName:listenerAName];
    [activator registerListener:listenerB forName:listenerBName];
    [activator registerListener:sharedListener forName:sharedListenerFirstName];
    [activator registerListener:sharedListener forName:sharedListenerSecondName];
    [activator registerListener:(id<LAListener>)simpleAbort forName:simpleAbortName];

    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:event toListenersWithNames:@[ listenerAName, listenerBName ]];
    [activator sendEventToListener:event];
    [recorder expect:event.handled && listenerA.receiveCount == 1 && listenerB.receiveCount == 1
            caseName:@"assigned-dispatch"
              reason:@"Assigned dispatch did not reach expected listeners"];
    [recorder expect:listenerB.otherHandledCount == 1
            caseName:@"other-listener-handled"
              reason:@"Other listener was not notified"];
    [recorder expect:sharedListener.otherHandledCount == 1
            caseName:@"shared-listener-other-handled-once"
              reason:@"Shared listener instance received duplicate handled notifications"];

    LAEvent *explicitEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:explicitEvent toListenersWithNames:@[ listenerBName ]];
    [recorder expect:listenerB.receiveCount == 2 caseName:@"explicit-dispatch" reason:@"Explicit dispatch failed"];

    listenerB.lastReceivedEventMode = LAEventModeSpringBoard;
    [activator sendEvent:[LAEvent eventWithName:eventName] toListenersWithNames:@[ listenerBName ]];
    [recorder expect:listenerB.lastReceivedEventMode == nil
            caseName:@"nil-mode-immediate-dispatch"
              reason:@"Immediate dispatch rewrote nil event mode"];

    listenerB.receiveCount = 0;
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
        toListenersWithNames:@[ listenerBName, listenerBName ]];
    [recorder expect:listenerB.receiveCount == 1
            caseName:@"explicit-dispatch-deduplicates-listeners"
              reason:@"Explicit dispatch delivered to a repeated listener name"];

    [activator sendAbortEvent:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]
         toListenersWithNames:@[ simpleAbortName ]];
    [recorder expect:simpleAbort.abortCount == 1
            caseName:@"abort-fallback"
              reason:@"Simple abort selector was not used"];

    [activator sendPreviewEventToListenerWithName:listenerAName];
    [recorder expect:listenerA.previewCount == 1 && listenerB.previewCount == 0
            caseName:@"preview-target"
              reason:@"Preview dispatch target mismatch"];

    LAEvent *deactivateEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendDeactivateEventToListeners:deactivateEvent];
    [recorder expect:deactivateEvent.handled && listenerA.deactivateCount == 1 && listenerB.deactivateCount == 1 &&
                     sharedListener.deactivateCount == 1
            caseName:@"deactivate-broadcast"
              reason:@"Deactivate broadcast failed"];
    [activator unregisterListenerWithName:sharedListenerFirstName];
    [activator sendDeactivateEventToListeners:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]];
    [recorder expect:sharedListener.deactivateCount == 2
            caseName:@"shared-listener-kept-after-one-name-removed"
              reason:@"Shared listener instance was removed before its last name"];
    [activator unregisterListenerWithName:sharedListenerSecondName];
    [activator sendDeactivateEventToListeners:[LAEvent eventWithName:eventName mode:LAEventModeSpringBoard]];
    [recorder expect:sharedListener.deactivateCount == 2
            caseName:@"shared-listener-removed-after-last-name"
              reason:@"Shared listener instance remained after its last name was removed"];

    listenerA.requiresNoTouchEvents = YES;
    listenerA.receiveCount = 0;
    listenerB.receiveCount = 0;
    listenerB.otherHandledCount = 0;
    listenerA.lastReceivedEventMode = LAEventModeSpringBoard;
    LAEvent *deferredEvent = [LAEvent eventWithName:eventName];
    [self sendSyntheticTouchWithTouching:YES];
    [self waitForSyntheticTouchDelivery];
    [activator sendEvent:deferredEvent toListenersWithNames:@[ listenerAName, listenerBName ]];
    [recorder expect:deferredEvent.handled && listenerA.receiveCount == 0
            caseName:@"deferred-no-touch-enqueue"
              reason:@"Deferred event was not held while touch was active"];
    [recorder expect:listenerB.receiveCount == 1
            caseName:@"deferred-no-touch-continues-next-listener"
              reason:@"Deferred no-touch dispatch blocked the next listener"];
    [recorder expect:listenerB.otherHandledCount == 1
            caseName:@"deferred-no-touch-notifies-next-listener"
              reason:@"Deferred no-touch dispatch did not notify the next listener"];
    listenerA.compatibleModes = @[];
    [self sendSyntheticTouchWithTouching:NO];
    [self waitForSyntheticTouchDelivery];
    [self waitForMainQueue];
    [recorder expect:listenerA.receiveCount == 1 && listenerB.receiveCount == 1
            caseName:@"deferred-no-touch-drain"
              reason:@"Deferred event did not dispatch after touch ended"];
    [recorder expect:listenerA.receiveCount == 1
            caseName:@"deferred-no-touch-direct-drain"
              reason:@"Deferred event was filtered during drain"];
    [recorder expect:listenerA.lastReceivedEventMode == nil
            caseName:@"nil-mode-deferred-dispatch"
              reason:@"Deferred dispatch rewrote nil event mode"];
}

+ (void)runBuiltInActionRegistryTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInActionRegistry"];

    NSString *eventName = @"libactivator.test.built-in.nothing";
    NSString *nothingName = @"libactivator.system.nothing";
    NSString *urlName = @"libactivator.clock.timer";
    NSString *urlsName = @"libactivator.settings.bluetooth";
    NSString *metadataOnlyName = @"libactivator.ipod.toggle-playback";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];

    [activator registerEventDataSource:dataSource forEventName:eventName];

    [recorder expect:[[activator availableListenerNames] containsObject:nothingName]
            caseName:@"nothing-registered"
              reason:@"Built-in nothing listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:nothingName]
            caseName:@"nothing-seen"
              reason:@"Built-in nothing listener was not recorded as seen"];
    [recorder
          expect:[[activator availableListenerNames] containsObject:urlName] && [activator hasListenerWithName:urlName]
        caseName:@"url-action-registered"
          reason:@"Built-in URL action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:urlName]
            caseName:@"url-action-seen"
              reason:@"Built-in URL action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:urlsName] &&
                     [activator hasListenerWithName:urlsName]
            caseName:@"urls-action-registered"
              reason:@"Built-in URL action with versioned metadata was not registered"];
    [recorder expect:![activator hasListenerWithName:metadataOnlyName]
            caseName:@"metadata-only-not-registered"
              reason:@"Non-URL staged metadata registered a listener without an implementation"];

    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:event toListenerWithName:nothingName];
    [activator sendEventToListener:event];
    [recorder expect:event.handled
            caseName:@"nothing-handles-event"
              reason:@"Built-in nothing listener did not mark the event handled"];
}

+ (void)runBuiltInURLActionTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInURLActions"];

    Class urlActionClass = NSClassFromString(@"LATURLActionListener");
    [recorder expect:urlActionClass != Nil
            caseName:@"url-action-class-available"
              reason:@"LATURLActionListener class was not loaded in SpringBoard"];
    if (!urlActionClass) {
        return;
    }

    NSString *eventName = @"libactivator.test.built-in.url";
    NSString *singleURLName = @"libactivator.clock.timer";
    NSString *versionedURLName = @"libactivator.settings.bluetooth";
    NSString *missingURLName = @"libactivator.test.url.missing";
    NSString *invalidURLName = @"libactivator.test.url.invalid";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    __block NSInteger openCount = 0;
    [activator registerEventDataSource:dataSource forEventName:eventName];

    [(id)urlActionClass resetTestingState];
    [(id)urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return YES;
    }];

    LAEvent *singleURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:singleURLEvent toListenerWithName:singleURLName];
    NSURL *singleURL = [(id)urlActionClass testingLastOpenedURL];
    NSString *singleListenerName = [(id)urlActionClass testingLastOpenedListenerName];
    [recorder expect:singleURLEvent.handled && openCount == 1
            caseName:@"single-url-handles-event"
              reason:@"URL action with single url metadata did not handle the event"];
    [recorder expect:[[singleURL absoluteString] isEqualToString:@"clock-timer:default"] &&
                     [singleListenerName isEqualToString:singleURLName]
            caseName:@"single-url-selection"
              reason:@"URL action did not open the single url metadata value"];

    LAEvent *versionedURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:versionedURLEvent toListenerWithName:versionedURLName];
    NSURL *versionedURL = [(id)urlActionClass testingLastOpenedURL];
    [recorder expect:versionedURLEvent.handled && openCount == 2
            caseName:@"versioned-url-handles-event"
              reason:@"URL action with versioned urls metadata did not handle the event"];
    [recorder expect:[[versionedURL absoluteString] isEqualToString:@"prefs:root=Bluetooth"]
            caseName:@"versioned-url-selection"
              reason:@"URL action did not select the current CoreFoundation URL"];

    [(id)urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return NO;
    }];
    LAEvent *openFailureEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:openFailureEvent toListenerWithName:singleURLName];
    [recorder expect:!openFailureEvent.handled && openCount == 3
            caseName:@"url-open-failure-unhandled"
              reason:@"URL action marked the event handled when the opener failed"];

    id testURLListener = [[urlActionClass alloc] init];
    [activator registerListener:testURLListener forName:missingURLName];
    [(id)urlActionClass resetTestingState];
    [(id)urlActionClass setTestingOpenHandler:^BOOL(NSURL *url, NSString *listenerName) {
        openCount += 1;
        return YES;
    }];
    LAEvent *missingURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:missingURLEvent toListenerWithName:missingURLName];
    [recorder expect:!missingURLEvent.handled && [(id)urlActionClass testingLastOpenedURL] == nil
            caseName:@"missing-url-metadata-unhandled"
              reason:@"URL action handled an event with no URL metadata"];

    [activator registerListener:testURLListener forName:invalidURLName];
    [(id)urlActionClass setTestingURLMetadata:@{@"url" : @"not a valid absolute URL"} forListenerName:invalidURLName];
    LAEvent *invalidURLEvent = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator sendEvent:invalidURLEvent toListenerWithName:invalidURLName];
    [recorder expect:!invalidURLEvent.handled && [(id)urlActionClass testingLastOpenedURL] == nil
            caseName:@"invalid-url-metadata-unhandled"
              reason:@"URL action handled an event with invalid URL metadata"];

    [(id)urlActionClass resetTestingState];
}

+ (void)runRuntimeInputTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"RuntimeInput"];

    [self cleanRuntimeInputStateWithActivator:activator];
    [activator la_noteHomeScreenVisible:YES source:@"test.home.a"];
    [activator la_noteHomeScreenVisible:YES source:@"test.home.b"];
    NSDictionary *homeAddedState = [activator la_runtimeStateDebugDictionary];
    NSArray *homeAddedSources = homeAddedState[@"HomeSources"];
    [recorder
          expect:[homeAddedSources containsObject:@"test.home.a"] && [homeAddedSources containsObject:@"test.home.b"]
        caseName:@"home-source-add"
          reason:[self runtimeDebugReasonWithPrefix:@"Home sources were not tracked" activator:activator]];

    [activator la_noteHomeScreenVisible:NO source:@"test.home.a"];
    NSDictionary *homeRemovedState = [activator la_runtimeStateDebugDictionary];
    NSArray *homeRemovedSources = homeRemovedState[@"HomeSources"];
    [recorder expect:![homeRemovedSources containsObject:@"test.home.a"] &&
                     [homeRemovedSources containsObject:@"test.home.b"]
            caseName:@"home-source-remove"
              reason:[self runtimeDebugReasonWithPrefix:@"Home source removal failed" activator:activator]];

    [activator la_noteHomeScreenVisible:NO];
    NSDictionary *homeClearedState = [activator la_runtimeStateDebugDictionary];
    [recorder expect:[homeClearedState[@"HomeSources"] count] == 0
            caseName:@"home-source-clear"
              reason:[self runtimeDebugReasonWithPrefix:@"Home source clear failed" activator:activator]];

    [activator la_noteLockScreenVisible:YES source:@"test.lock.a"];
    [activator la_noteLockScreenVisible:YES source:@"test.lock.b"];
    NSDictionary *lockAddedState = [activator la_runtimeStateDebugDictionary];
    NSArray *lockAddedSources = lockAddedState[@"LockSources"];
    [recorder
          expect:[lockAddedSources containsObject:@"test.lock.a"] && [lockAddedSources containsObject:@"test.lock.b"]
        caseName:@"lock-source-add"
          reason:[self runtimeDebugReasonWithPrefix:@"Lock sources were not tracked" activator:activator]];

    [activator la_noteLockScreenVisible:NO source:@"test.lock.a"];
    NSDictionary *lockRemovedState = [activator la_runtimeStateDebugDictionary];
    NSArray *lockRemovedSources = lockRemovedState[@"LockSources"];
    [recorder expect:![lockRemovedSources containsObject:@"test.lock.a"] &&
                     [lockRemovedSources containsObject:@"test.lock.b"]
            caseName:@"lock-source-remove"
              reason:[self runtimeDebugReasonWithPrefix:@"Lock source removal failed" activator:activator]];

    [activator la_noteLockScreenVisible:NO];
    NSDictionary *lockClearedState = [activator la_runtimeStateDebugDictionary];
    [recorder expect:[lockClearedState[@"LockSources"] count] == 0
            caseName:@"lock-source-clear"
              reason:[self runtimeDebugReasonWithPrefix:@"Lock source clear failed" activator:activator]];

    [activator la_noteScreenBlanked:YES];
    [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeLockScreen]
            caseName:@"screen-blanked-mode"
              reason:[self runtimeDebugReasonWithPrefix:@"Blank screen did not report lockscreen mode"
                                              activator:activator]];
    [activator la_noteScreenBlanked:NO];
    [activator la_noteRuntimeStateMayHaveChanged];

    NSString *eventName = @"libactivator.test.dispatch";
    NSString *unlockingListenerName = @"libactivator.test.dispatch.unlock";
    NSString *lockScreenListenerName = @"libactivator.test.dispatch.lock";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
    LATestListener *unlockingListener = [[LATestListener alloc] init];
    LATestListener *lockScreenListener = [[LATestListener alloc] init];
    unlockingListener.compatibleModes = @[ LAEventModeSpringBoard ];
    lockScreenListener.compatibleModes = @[ LAEventModeLockScreen ];
    dataSource.supportsUnlockingDeviceToSend = YES;
    [activator registerEventDataSource:dataSource forEventName:eventName];
    [activator registerListener:unlockingListener forName:unlockingListenerName];
    [activator registerListener:lockScreenListener forName:lockScreenListenerName];
    [activator la_noteHomeScreenVisible:YES];
    [activator la_noteLockScreenVisible:YES];
    [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeLockScreen]
        toListenersWithNames:@[ unlockingListenerName, lockScreenListenerName ]];
    [recorder expect:unlockingListener.unlockingCount == 1
            caseName:@"unlock-to-send-callback"
              reason:@"Unlock-to-send callback did not run"];
    [recorder expect:lockScreenListener.receiveCount == 0
            caseName:@"unlock-to-send-stops-normal-dispatch"
              reason:@"Lock screen listener received an event after unlock-to-send handled it"];

    [self cleanRuntimeInputStateWithActivator:activator];
}

+ (void)runRuntimeDeviceTestsWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"RuntimeDevice"];

    if ([self isDeviceLocked]) {
        [self unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""];
        [self waitAllowingMainRunLoopForTimeInterval:1.0];
    }

    if (![self resetHomeScreen]) {
        [recorder skip:@"home-mode" reason:@"Home automation is unavailable"];
    } else if ([self isDeviceLocked]) {
        [recorder skip:@"home-mode" reason:@"Device is locked"];
    } else {
        [self waitAllowingMainRunLoopForTimeInterval:1.5];
        [self waitForMainQueue];
        [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeSpringBoard]
                caseName:@"home-mode"
                  reason:[self runtimeDebugReasonWithPrefix:@"Home screen did not report springboard mode"
                                                  activator:activator]];
    }

    if (![self prepareApplicationModeWithBundleIdentifier:@"com.apple.Preferences" activator:activator attempts:3]) {
        [recorder skip:@"application-mode" reason:@"Application launch automation is unavailable"];
    } else {
        [self waitForMainQueue];
        NSString *frontMost = [self frontMostDisplayIdentifier];
        [recorder expect:[frontMost isEqualToString:@"com.apple.Preferences"] ||
                         [activator.displayIdentifierForCurrentApplication isEqualToString:@"com.apple.Preferences"]
                caseName:@"application-frontmost"
                  reason:@"Preferences did not become frontmost"];
        [recorder expect:[activator.currentEventMode isEqualToString:LAEventModeApplication]
                caseName:@"application-mode"
                  reason:[self runtimeDebugReasonWithPrefix:@"Foreground app did not report application mode"
                                                  activator:activator]];

        NSString *eventName = @"libactivator.test.dispatch";
        NSString *listenerName = @"libactivator.test.dispatch.a";
        LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];
        LATestListener *listener = [[LATestListener alloc] init];
        [activator registerEventDataSource:dataSource forEventName:eventName];
        [activator registerListener:listener forName:listenerName];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:YES];
        [activator sendEvent:[LAEvent eventWithName:eventName mode:LAEventModeApplication]
            toListenersWithNames:@[ listenerName ]];
        [recorder expect:listener.receiveCount == 0
                caseName:@"explicit-dispatch-respects-blacklist"
                  reason:@"Explicit dispatch ignored the foreground application blacklist"];
        [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    }

    if (![self lockDevice]) {
        [recorder skip:@"lockscreen-mode" reason:@"Lock automation is unavailable"];
    } else {
        [self waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:[self isDeviceLocked] || [activator.currentEventMode isEqualToString:LAEventModeLockScreen]
                caseName:@"lockscreen-mode"
                  reason:@"Lock screen did not report lockscreen mode"];
    }

    if (![self unlockDeviceWithPasscode:NSProcessInfo.processInfo.environment[@"LA_TEST_PASSCODE"] ?: @""]) {
        [recorder skip:@"unlock-device" reason:@"Unlock automation is unavailable"];
    } else {
        [self waitAllowingMainRunLoopForTimeInterval:1.0];
        [recorder expect:![self isDeviceLocked] caseName:@"unlock-device" reason:@"Device is still locked"];
    }

    [self suspendApplication];
}

#pragma mark - Cleanup

+ (void)cleanActivator:(LAActivator *)activator {
    NSArray *listenerNames = @[
        @"libactivator.test.listener.a",
        @"libactivator.test.listener.b",
        @"libactivator.test.listener.c",
        @"libactivator.test.listener.unseen",
        @"libactivator.test.listener.new",
        @"libactivator.test.listener.localization",
        @"libactivator.test.listener.icon",
        @"libactivator.test.dispatch.a",
        @"libactivator.test.dispatch.b",
        @"libactivator.test.dispatch.shared.first",
        @"libactivator.test.dispatch.shared.second",
        @"libactivator.test.dispatch.simple-abort",
        @"libactivator.test.dispatch.lock",
        @"libactivator.test.dispatch.unlock",
        @"libactivator.test.client-facade.user-info",
        @"libactivator.test.url.missing",
        @"libactivator.test.url.invalid",
    ];
    for (NSString *listenerName in listenerNames) {
        [activator unregisterListenerWithName:listenerName];
    }

    NSArray *eventNames = @[
        @"libactivator.test.core",
        @"libactivator.test.removable-event",
        @"libactivator.test.nonremovable-event",
        @"libactivator.test.new-event-data-source",
        @"libactivator.test.dispatch",
        @"libactivator.test.built-in.nothing",
        @"libactivator.test.built-in.url",
        @"libactivator.test.client-facade.user-info",
    ];
    for (NSString *eventName in eventNames) {
        [activator unregisterEventDataSourceWithEventName:eventName];
        for (NSString *mode in activator.availableEventModes) {
            [activator unassignEvent:[LAEvent eventWithName:eventName mode:mode]];
        }
    }
    [activator setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [activator setCurrentProfileName:@"Default"];
    [self sendSyntheticTouchWithTouching:NO];
    [self waitForSyntheticTouchDelivery];
}

+ (void)cleanRuntimeInputStateWithActivator:(LAActivator *)activator {
    [activator la_noteHomeScreenVisible:NO];
    [activator la_noteLockScreenVisible:NO];
    [activator la_noteScreenBlanked:NO];
    [activator la_noteRuntimeStateMayHaveChanged];
}

+ (void)removeTestPlist {
    [NSFileManager.defaultManager removeItemAtPath:jbroot(@"/var/mobile/Library/Preferences/libactivator.tests.plist")
                                             error:nil];
}

#pragma mark - Synthetic Touches

+ (void)sendSyntheticTouchWithTouching:(BOOL)touching {
    uint64_t machTimeValue = mach_absolute_time();
    AbsoluteTime machTime;
#if TARGET_RT_BIG_ENDIAN
    machTime.hi = (UInt32)(machTimeValue >> 32);
    machTime.lo = (UInt32)machTimeValue;
#else
    machTime.lo = (UInt32)machTimeValue;
    machTime.hi = (UInt32)(machTimeValue >> 32);
#endif
    uint32_t eventMask = kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventRange | kIOHIDDigitizerEventIdentity;
    IOHIDEventRef event =
        IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, machTime, kIOHIDDigitizerTransducerTypeHand, 0, 0,
                                       eventMask, 0, 0, 0, 0, 0, 0, touching, touching, 0);
    if (!event) {
        return;
    }

    IOHIDEventSetIntegerValue(event, LATestHIDEventFieldIsBuiltIn, 1);
    IOHIDEventSetIntegerValue(event, LATestHIDEventFieldDigitizerIsDisplayIntegrated, 1);

    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, machTime, 2, 2, eventMask, 0.5,
                                                                0.5, 0, 0, 90.0, touching, touching, 0);
    if (finger) {
        IOHIDEventSetFloatValue(finger, kIOHIDEventFieldDigitizerMinorRadius, 5.0);
        IOHIDEventSetFloatValue(finger, kIOHIDEventFieldDigitizerMajorRadius, 5.0);
        IOHIDEventAppendEvent(event, finger);
        CFRelease(finger);
    }

    static IOHIDEventSystemClientRef client = nil;
    static dispatch_once_t clientOnceToken;
    dispatch_once(&clientOnceToken, ^{
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    });

    static dispatch_queue_t queue = nil;
    static dispatch_once_t queueOnceToken;
    dispatch_once(&queueOnceToken, ^{
        queue = dispatch_queue_create("libactivator.tests.hid-events", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    });

    IOHIDEventRef eventToDispatch = (IOHIDEventRef)CFRetain(event);
    dispatch_async(queue, ^{
        IOHIDEventSetSenderID(eventToDispatch, LATestHIDSenderID);
        IOHIDEventSystemClientDispatchEvent(client, eventToDispatch);
        CFRelease(eventToDispatch);
    });
    CFRelease(event);
}

+ (void)waitForSyntheticTouchDelivery {
    [self waitAllowingMainRunLoopForTimeInterval:0.25];
    [self waitForMainQueue];
}

#pragma mark - Device Automation

+ (BOOL)resetHomeScreen {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class automationClass = NSClassFromString(@"SBSTestAutomationService");
        id service = automationClass ? [[automationClass alloc] init] : nil;
        if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:useSafeTransitions:)]) {
            [service resetToHomeScreenAnimated:NO useSafeTransitions:YES];
            attempted = YES;
        } else if ([service respondsToSelector:@selector(resetToHomeScreenAnimated:)]) {
            [service resetToHomeScreenAnimated:NO];
            attempted = YES;
        } else {
            Class springBoardClass = NSClassFromString(@"SpringBoard");
            id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                                 ? [springBoardClass sharedApplication]
                                 : UIApplication.sharedApplication;
            if ([springBoard respondsToSelector:@selector(suspend)]) {
                [springBoard suspend];
                attempted = YES;
            }
        }
    }];
    return attempted;
}

+ (BOOL)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    __block BOOL opened = NO;
    [self performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                             ? [springBoardClass sharedApplication]
                             : UIApplication.sharedApplication;
        if ([springBoard respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
            [springBoard launchApplicationWithIdentifier:bundleIdentifier suspended:NO];
            opened = YES;
        }
    }];
    return opened;
}

+ (BOOL)prepareApplicationModeWithBundleIdentifier:(NSString *)bundleIdentifier
                                         activator:(LAActivator *)activator
                                          attempts:(NSUInteger)attempts {
    BOOL openedAtLeastOnce = NO;
    NSUInteger effectiveAttempts = attempts > 0 ? attempts : 1;
    for (NSUInteger attempt = 0; attempt < effectiveAttempts; attempt++) {
        if (![self openApplicationWithBundleIdentifier:bundleIdentifier]) {
            continue;
        }
        openedAtLeastOnce = YES;
        [self waitForFrontMostApplicationWithBundleIdentifier:bundleIdentifier timeout:5.0];
        [self waitAllowingMainRunLoopForTimeInterval:0.75];
        [self waitForMainQueue];
        if ([activator.currentEventMode isEqualToString:LAEventModeApplication] &&
            [activator.displayIdentifierForCurrentApplication isEqualToString:bundleIdentifier]) {
            return YES;
        }
        if (attempt + 1 < effectiveAttempts && [self resetHomeScreen]) {
            [self waitAllowingMainRunLoopForTimeInterval:1.0];
            [self waitForMainQueue];
        }
    }
    return openedAtLeastOnce;
}

+ (BOOL)suspendApplication {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class springBoardClass = NSClassFromString(@"SpringBoard");
        id springBoard = [springBoardClass respondsToSelector:@selector(sharedApplication)]
                             ? [springBoardClass sharedApplication]
                             : UIApplication.sharedApplication;
        if ([springBoard respondsToSelector:@selector(suspend)]) {
            [springBoard suspend];
            attempted = YES;
        }
    }];
    return attempted;
}

+ (BOOL)lockDevice {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(remoteLock:)]) {
            [manager remoteLock:YES];
            attempted = YES;
            Class backlightClass = NSClassFromString(@"SBBacklightController");
            id backlight =
                [backlightClass respondsToSelector:@selector(sharedInstance)] ? [backlightClass sharedInstance] : nil;
            if ([backlight respondsToSelector:@selector(_startFadeOutAnimationFromLockSource:)]) {
                [backlight _startFadeOutAnimationFromLockSource:1];
            }
            return;
        }
    }];
    return attempted;
}

+ (BOOL)unlockDeviceWithPasscode:(NSString *)passcode {
    __block BOOL attempted = NO;
    [self performOnMainThreadSynchronously:^{
        Class backlightClass = NSClassFromString(@"SBBacklightController");
        id backlight =
            [backlightClass respondsToSelector:@selector(sharedInstance)] ? [backlightClass sharedInstance] : nil;
        if ([backlight respondsToSelector:@selector(turnOnScreenFullyWithBacklightSource:)]) {
            [backlight turnOnScreenFullyWithBacklightSource:1];
        }

        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:finishUIUnlock:completion:)]) {
            [manager attemptUnlockWithPasscode:passcode ?: @"" finishUIUnlock:YES completion:nil];
            attempted = YES;
        } else if ([manager respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
            [manager attemptUnlockWithPasscode:passcode ?: @""];
            attempted = YES;
        } else {
            attempted = [self resetHomeScreen];
        }
    }];
    return attempted;
}

+ (BOOL)isDeviceLocked {
    __block BOOL locked = NO;
    void (^readLockState)(void) = ^{
        Class managerClass = NSClassFromString(@"SBLockScreenManager");
        id manager = [managerClass respondsToSelector:@selector(sharedInstance)] ? [managerClass sharedInstance] : nil;
        if ([manager respondsToSelector:@selector(isUILocked)]) {
            locked = [manager isUILocked];
        }
    };
    [self performOnMainThreadSynchronously:readLockState];
    return locked;
}

+ (NSString *)frontMostDisplayIdentifier {
    __block NSString *displayIdentifier = nil;
    void (^readFrontMostApplication)(void) = ^{
        UIApplication *application = UIApplication.sharedApplication;
        if (![application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
            return;
        }

        id<LAActivatorTestingApplication> frontMostApplication = [application _accessibilityFrontMostApplication];
        if ([frontMostApplication respondsToSelector:@selector(bundleIdentifier)]) {
            displayIdentifier = [frontMostApplication bundleIdentifier];
        }
        if (displayIdentifier.length == 0 && [frontMostApplication respondsToSelector:@selector(displayIdentifier)]) {
            displayIdentifier = [frontMostApplication displayIdentifier];
        }
    };
    [self performOnMainThreadSynchronously:readFrontMostApplication];
    return displayIdentifier;
}

+ (BOOL)waitForFrontMostApplicationWithBundleIdentifier:(NSString *)bundleIdentifier timeout:(NSTimeInterval)timeout {
    if (bundleIdentifier.length == 0) {
        return NO;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        if ([[self frontMostDisplayIdentifier] isEqualToString:bundleIdentifier]) {
            return YES;
        }
        [self waitAllowingMainRunLoopForTimeInterval:0.1];
    }
    return [[self frontMostDisplayIdentifier] isEqualToString:bundleIdentifier];
}

+ (NSString *)runtimeDebugReasonWithPrefix:(NSString *)prefix activator:(LAActivator *)activator {
    NSDictionary *state = [activator la_runtimeStateDebugDictionary];
    return [NSString stringWithFormat:@"%@; mode=%@; homeSources=%@; springBoardSources=%@; lockSources=%@; "
                                      @"screenOn=%@; uiLocked=%@; frontMost=%@",
                                      prefix ?: @"Runtime mode mismatch", state[@"Mode"] ?: @"",
                                      state[@"HomeSources"] ?: @[], state[@"SpringBoardInterfaceSources"] ?: @[],
                                      state[@"LockSources"] ?: @[], state[@"ScreenOn"] ?: @NO,
                                      state[@"UILocked"] ?: @NO, state[@"FrontMost"] ?: @""];
}

+ (void)performOnMainThreadSynchronously:(dispatch_block_t)block {
    if (!block) {
        return;
    }
    if (NSThread.isMainThread) {
        block();
        return;
    }
    dispatch_sync(dispatch_get_main_queue(), block);
}

+ (void)waitAllowingMainRunLoopForTimeInterval:(NSTimeInterval)timeInterval {
    if (timeInterval <= 0) {
        return;
    }
    if (!NSThread.isMainThread) {
        [NSThread sleepForTimeInterval:timeInterval];
        return;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    while ([deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

+ (void)waitForMainQueue {
    if (!NSThread.isMainThread) {
        dispatch_sync(dispatch_get_main_queue(), ^{
                      });
        return;
    }

    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        drained = YES;
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!drained && [deadline timeIntervalSinceNow] > 0) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end

#endif
