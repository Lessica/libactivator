//
//  LATestBuiltInListenerCompositionSuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInListenerCompositionSuite.h"

#import "LATBuiltInListenerRegistrant.h"
#import "LATBuiltInRegistry.h"
#import "LATCameraActionListener.h"
#import "LATComposeActionListener.h"
#import "LATHardwareActionListener.h"
#import "LATNothingListener.h"
#import "LATSpringBoardInstanceProviding.h"
#import "LATSystemActionListener.h"
#import "LATTelephonyActionListener.h"
#import "LATURLActionListener.h"
#import "LATestEventDataSource.h"
#import "LATestRecorder.h"

#import <Activator/Activator.h>

@interface LATestMissingListenerMetadataActivator : NSObject
@end

@implementation LATestMissingListenerMetadataActivator

- (id)infoDictionaryValueOfKey:(__unused NSString *)key forListenerWithName:(__unused NSString *)listenerName {
    return nil;
}

@end

@implementation LATestBuiltInListenerCompositionSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInListenerComposition"];

    NSString *eventName = @"libactivator.test.built-in.nothing";
    NSString *nothingName = @"libactivator.system.nothing";
    NSString *urlName = @"libactivator.clock.timer";
    NSString *urlsName = @"libactivator.settings.bluetooth";
    NSString *phoneURLName = @"libactivator.phone.recents";
    NSString *hardwareName = @"libactivator.ipod.toggle-playback";
    NSString *hardwareSystemName = @"libactivator.system.spotlight";
    NSString *nowPlayingName = @"libactivator.audio.launch-playing-app";
    NSString *ringerName = @"libactivator.audio.reset-ringer-state";
    NSString *softRebootName = @"libactivator.system.soft-reboot";
    NSString *telephonyName = @"libactivator.phone.answer-call";
    NSString *metadataOnlyName = @"libactivator.watch.haptic.tap";
    LATestEventDataSource *dataSource = [[LATestEventDataSource alloc] init];

    NSArray<Class> *expectedListenerClasses = @[
        LATNothingListener.class,
        LATURLActionListener.class,
        LATHardwareActionListener.class,
        LATSystemActionListener.class,
        LATComposeActionListener.class,
        LATCameraActionListener.class,
        LATTelephonyActionListener.class,
    ];
    NSArray<Class> *listenerClasses = [LATBuiltInRegistry builtInListenerClasses];
    NSMutableSet<NSString *> *listenerNames = [[NSMutableSet alloc] init];
    BOOL usesUniformInitializer =
        [(id)LATBuiltInRegistry.class conformsToProtocol:@protocol(LATSpringBoardInstanceProviding)] &&
        [LATBuiltInListenerContext instancesRespondToSelector:@selector(runtimeStateSource)] &&
        [LATBuiltInListenerContext instancesRespondToSelector:@selector(springBoardInstanceProvider)] &&
        [LATBuiltInListenerContext instancesRespondToSelector:@selector(eventSourceConformingToProtocol:)] &&
        ![LATBuiltInListenerContext instancesRespondToSelector:NSSelectorFromString(@"registry")] &&
        listenerClasses.count == expectedListenerClasses.count;
    BOOL ownsUniqueListenerNames = YES;
    BOOL metadataGatesAcceptBundledNames = YES;
    BOOL metadataGatesRejectMissingMetadata = YES;
    BOOL metadataGatesRejectUnknownNames = YES;
    LAActivator *missingMetadataActivator = (LAActivator *)[[LATestMissingListenerMetadataActivator alloc] init];
    for (Class rawListenerClass in listenerClasses) {
        BOOL conformsToRegistrant = [(id)rawListenerClass conformsToProtocol:@protocol(LATBuiltInListenerRegistrant)];
        usesUniformInitializer =
            usesUniformInitializer && conformsToRegistrant &&
            [rawListenerClass instancesRespondToSelector:@selector(initWithBuiltInListenerContext:)];
        if (!conformsToRegistrant) {
            continue;
        }

        Class<LATBuiltInListenerRegistrant> listenerClass = (Class<LATBuiltInListenerRegistrant>)rawListenerClass;
        NSArray<NSString *> *supportedListenerNames = [listenerClass supportedListenerNames];
        usesUniformInitializer = usesUniformInitializer && supportedListenerNames.count > 0;
        metadataGatesRejectUnknownNames = metadataGatesRejectUnknownNames &&
                                          ![listenerClass listenerNameHasRequiredMetadata:@"libactivator.test.unknown"
                                                                                activator:activator];
        for (NSString *listenerName in supportedListenerNames) {
            if (![listenerName isKindOfClass:NSString.class] || listenerName.length == 0 ||
                [listenerNames containsObject:listenerName]) {
                ownsUniqueListenerNames = NO;
                continue;
            }
            [listenerNames addObject:listenerName];
            metadataGatesAcceptBundledNames =
                metadataGatesAcceptBundledNames && [listenerClass listenerNameHasRequiredMetadata:listenerName
                                                                                        activator:activator];
            metadataGatesRejectMissingMetadata =
                metadataGatesRejectMissingMetadata &&
                ![listenerClass listenerNameHasRequiredMetadata:listenerName activator:missingMetadataActivator];
        }
    }
    [recorder expect:usesUniformInitializer && [listenerClasses isEqualToArray:expectedListenerClasses] &&
                     [NSSet setWithArray:listenerClasses].count == listenerClasses.count
            caseName:@"built-in-listener-class-list-is-complete-and-uniform"
              reason:@"The built-in listener class list changed order, contains duplicates, or bypasses the uniform "
                     @"initializer"];
    [recorder expect:ownsUniqueListenerNames && metadataGatesAcceptBundledNames && metadataGatesRejectMissingMetadata &&
                     metadataGatesRejectUnknownNames
            caseName:@"built-in-listener-names-have-one-owner-and-metadata-gate"
              reason:@"A built-in listener name has multiple owners or does not obey the shared metadata gate"];

    [activator registerEventDataSource:dataSource forEventName:eventName];

    [recorder expect:[[activator availableListenerNames] containsObject:nothingName]
            caseName:@"nothing-registered"
              reason:@"Built-in nothing listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:nothingName]
            caseName:@"nothing-seen"
              reason:@"Built-in nothing listener was not recorded as seen"];
    [recorder expect:[activator listenerWithName:nothingName isCompatibleWithEventName:LAEventNameLockPressDouble]
            caseName:@"nothing-compatible-with-lock-double-press"
              reason:@"Built-in nothing listener should be assignable to lock double press for no-op suppression"];
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
    [recorder expect:[[activator availableListenerNames] containsObject:phoneURLName] &&
                     [activator hasListenerWithName:phoneURLName]
            caseName:@"phone-url-action-registered"
              reason:@"Built-in Phone tab URL action listener was not registered"];
    [recorder expect:[[activator availableListenerNames] containsObject:hardwareName] &&
                     [activator hasListenerWithName:hardwareName]
            caseName:@"hardware-action-registered"
              reason:@"Built-in hardware action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:hardwareName]
            caseName:@"hardware-action-seen"
              reason:@"Built-in hardware action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:hardwareSystemName] &&
                     [activator hasListenerWithName:hardwareSystemName]
            caseName:@"hardware-system-action-registered"
              reason:@"Built-in HID-backed system action listener was not registered"];
    [recorder expect:[[activator availableListenerNames] containsObject:nowPlayingName] &&
                     [activator hasListenerWithName:nowPlayingName]
            caseName:@"system-now-playing-action-registered"
              reason:@"Built-in now-playing application action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:nowPlayingName]
            caseName:@"system-now-playing-action-seen"
              reason:@"Built-in now-playing application action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:ringerName] &&
                     [activator hasListenerWithName:ringerName]
            caseName:@"ringer-action-registered"
              reason:@"Built-in ringer action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:ringerName]
            caseName:@"ringer-action-seen"
              reason:@"Built-in ringer action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:softRebootName] &&
                     [activator hasListenerWithName:softRebootName]
            caseName:@"soft-reboot-action-registered"
              reason:@"Built-in soft reboot action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:softRebootName]
            caseName:@"soft-reboot-action-seen"
              reason:@"Built-in soft reboot action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:telephonyName] &&
                     [activator hasListenerWithName:telephonyName]
            caseName:@"telephony-action-registered"
              reason:@"Built-in telephony action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:telephonyName]
            caseName:@"telephony-action-seen"
              reason:@"Built-in telephony action listener was not recorded as seen"];
    [recorder expect:![activator hasListenerWithName:metadataOnlyName]
            caseName:@"metadata-only-not-registered"
              reason:@"Staged metadata registered a listener without an implementation"];

    LAEvent *event = [LAEvent eventWithName:eventName mode:LAEventModeSpringBoard];
    [activator assignEvent:event toListenerWithName:nothingName];
    [activator sendEventToListener:event];
    [recorder expect:event.handled
            caseName:@"nothing-handles-event"
              reason:@"Built-in nothing listener did not mark the event handled"];
}

@end
