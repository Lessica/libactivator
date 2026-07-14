//
//  LATestPersistenceSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestPersistenceSuite.h"

#import "LAPersistence.h"
#import "LAServerBackend.h"
#import "LATestCountingPersistence.h"
#import "LATestEnvironment.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@implementation LATestPersistenceSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder {
    [recorder beginSuite:@"Persistence"];

    NSString *path = [LATestEnvironment testCachePathWithFileName:@"libactivator.tests.persistence.plist"];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    LAPersistence *persistence = [[LAPersistence alloc] initWithFilePath:path];
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
    LAServerBackend *backend = [[LAServerBackend alloc] initWithPersistence:countingPersistence];
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
    NSDictionary *firstSavedDictionary = countingPersistence.lastSavedDictionary;
    [backend assignEvent:event toListenersWithNames:@[ @"libactivator.test.listener.two" ]];
    NSArray *firstSavedListenerNames =
        firstSavedDictionary[@"Profiles"][@"Testing"][@"Assignments"][event.name][event.mode];
    [recorder expect:[firstSavedListenerNames isEqualToArray:@[ @"libactivator.test.listener.one" ]]
            caseName:@"snapshot-is-detached"
              reason:@"Saved backend snapshot changed after later in-memory mutations"];
    NSMutableDictionary *mutableLegacyPreference = [@{@"Value" : @"Original"} mutableCopy];
    [recorder expect:[backend setObject:mutableLegacyPreference forLegacyPreferenceKey:@"MutableLegacyPreference"]
            caseName:@"legacy-preference-save"
              reason:@"Mutable legacy preference was not accepted"];
    mutableLegacyPreference[@"Value"] = @"Changed";
    [recorder expect:[[backend objectForLegacyPreferenceKey:@"MutableLegacyPreference"][@"Value"] isEqual:@"Original"]
            caseName:@"legacy-preference-detached"
              reason:@"Stored legacy preference retained a mutable caller-owned object"];
    [backend setApplicationWithDisplayIdentifier:@"com.apple.Preferences" isBlacklisted:NO];
    [recorder expect:countingPersistence.saveCount == 1 &&
                     ![backend applicationWithDisplayIdentifierIsBlacklisted:@"com.apple.Preferences"]
            caseName:@"coalesced-next-dirty"
              reason:@"Second mutation should update memory before the next flush"];
    [recorder expect:[backend flushPendingPersistentState] && countingPersistence.saveCount == 2
            caseName:@"coalesced-next-flush"
              reason:@"Second dirty pass did not schedule a new save"];

    NSMutableString *mutableListenerName = [@"libactivator.test.listener.mutable" mutableCopy];
    [backend assignEvent:event toListenersWithNames:@[ mutableListenerName ]];
    [mutableListenerName appendString:@".changed"];
    [recorder expect:[[backend assignedListenerNamesForEvent:event]
                         isEqualToArray:@[ @"libactivator.test.listener.mutable" ]]
            caseName:@"assignment-string-detached"
              reason:@"Stored assignment retained a caller-owned mutable string"];

    LATestCountingPersistence *debugAssignmentPersistence =
        [[LATestCountingPersistence alloc] initWithFilePath:@"libactivator-debug-assignment-tests.plist"];
    LAServerBackend *debugAssignmentBackend = [[LAServerBackend alloc] initWithPersistence:debugAssignmentPersistence];
    LAEvent *debugAssignmentEvent = [LAEvent eventWithName:@"libactivator.test.debug-assignment"
                                                      mode:LAEventModeSpringBoard];
    [debugAssignmentBackend setCurrentProfileNameIfChanged:@"DebugA"];
    [debugAssignmentBackend assignEvent:debugAssignmentEvent
                   toListenersWithNames:@[ @"libactivator.test.unavailable-listener" ]];
    NSDictionary *debugAssignmentSnapshot = debugAssignmentBackend.debugAssignmentSnapshot;
    [recorder expect:[debugAssignmentSnapshot[debugAssignmentEvent.name][debugAssignmentEvent.mode]
                         isEqualToArray:@[ @"libactivator.test.unavailable-listener" ]]
            caseName:@"debug-assignment-snapshot-is-authoritative"
              reason:@"Debug assignment snapshot filtered an unavailable assignment"];
    [debugAssignmentBackend setCurrentProfileNameIfChanged:@"DebugB"];
    [debugAssignmentBackend assignEvent:debugAssignmentEvent
                   toListenersWithNames:@[ @"libactivator.test.other-profile-listener" ]];
    BOOL firstDebugResetChanged = [debugAssignmentBackend debugResetAssignmentsForCurrentProfile];
    BOOL secondDebugResetChanged = [debugAssignmentBackend debugResetAssignmentsForCurrentProfile];
    [debugAssignmentBackend setCurrentProfileNameIfChanged:@"DebugA"];
    [recorder expect:firstDebugResetChanged && !secondDebugResetChanged &&
                     debugAssignmentBackend.debugAssignmentSnapshot.count == 1
            caseName:@"debug-assignment-reset-is-profile-scoped"
              reason:@"Debug assignment reset changed the wrong profile or reported an inaccurate result"];

    NSMutableString *mutableDisplayIdentifier = [@"com.example.Mutable" mutableCopy];
    [backend setApplicationWithDisplayIdentifier:mutableDisplayIdentifier isBlacklisted:YES];
    [mutableDisplayIdentifier appendString:@".changed"];
    [recorder expect:[backend applicationWithDisplayIdentifierIsBlacklisted:@"com.example.Mutable"]
            caseName:@"blacklist-string-detached"
              reason:@"Stored blacklist entry retained a caller-owned mutable string"];

    NSMutableDictionary *invalidNestedPreference = [@{
        @"Safe" : @"value",
        @"Unsafe" : [[NSObject alloc] init],
    } mutableCopy];
    [recorder expect:![backend setObject:invalidNestedPreference forLegacyPreferenceKey:@"InvalidNestedPreference"] &&
                     [backend objectForLegacyPreferenceKey:@"InvalidNestedPreference"] == nil
            caseName:@"legacy-preference-rejects-invalid-nested-value"
              reason:@"Invalid nested legacy preference was partially stored"];

    LATestCountingPersistence *failingPersistence =
        [[LATestCountingPersistence alloc] initWithFilePath:@"libactivator-failing-tests.plist"];
    failingPersistence.failsSaves = YES;
    LAServerBackend *failedSaveBackend = [[LAServerBackend alloc] initWithPersistence:failingPersistence];
    [failedSaveBackend setCurrentProfileNameIfChanged:@"Retry"];
    BOOL firstFlushFailed = ![failedSaveBackend flushPendingPersistentState];
    failingPersistence.failsSaves = NO;
    BOOL subsequentExplicitFlushSucceeded = [failedSaveBackend flushPendingPersistentState];
    [recorder expect:firstFlushFailed && subsequentExplicitFlushSucceeded && failingPersistence.saveCount == 2 &&
                     [failingPersistence.lastSavedDictionary[@"CurrentProfileName"] isEqualToString:@"Retry"]
            caseName:@"failed-save-remains-dirty"
              reason:@"Failed persistence save was not retained for a subsequent explicit flush"];

    LATestCountingPersistence *concurrentPersistence =
        [[LATestCountingPersistence alloc] initWithFilePath:@"libactivator-concurrent-tests.plist"];
    concurrentPersistence.saveDelay = 0.05;
    concurrentPersistence.saveStartedSemaphore = dispatch_semaphore_create(0);
    LAServerBackend *concurrentBackend = [[LAServerBackend alloc] initWithPersistence:concurrentPersistence];
    [concurrentBackend setCurrentProfileNameIfChanged:@"First"];
    dispatch_group_t saveGroup = dispatch_group_create();
    __block BOOL firstConcurrentFlushSucceeded = NO;
    __block BOOL secondConcurrentFlushSucceeded = NO;
    dispatch_group_async(saveGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        firstConcurrentFlushSucceeded = [concurrentBackend flushPendingPersistentState];
    });
    long saveStarted = dispatch_semaphore_wait(concurrentPersistence.saveStartedSemaphore,
                                               dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)));
    [concurrentBackend setCurrentProfileNameIfChanged:@"Second"];
    dispatch_group_async(saveGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        secondConcurrentFlushSucceeded = [concurrentBackend flushPendingPersistentState];
    });
    long savesFinished = dispatch_group_wait(saveGroup, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    [recorder expect:saveStarted == 0 && savesFinished == 0 && firstConcurrentFlushSucceeded &&
                     secondConcurrentFlushSucceeded && concurrentPersistence.maximumConcurrentSaveCount == 1 &&
                     concurrentPersistence.saveCount == 2 &&
                     [concurrentPersistence.lastSavedDictionary[@"CurrentProfileName"] isEqualToString:@"Second"]
            caseName:@"persistence-writes-serialized"
              reason:@"Concurrent persistence flushes overlapped or wrote a stale snapshot last"];

    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

@end
