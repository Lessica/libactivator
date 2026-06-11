//
//  LATestBuiltInActionRegistrySuite.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInActionRegistrySuite.h"

#import "LATestEnvironment.h"

@implementation LATestBuiltInActionRegistrySuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInActionRegistry"];

    NSString *eventName = @"libactivator.test.built-in.nothing";
    NSString *nothingName = @"libactivator.system.nothing";
    NSString *urlName = @"libactivator.clock.timer";
    NSString *urlsName = @"libactivator.settings.bluetooth";
    NSString *phoneURLName = @"libactivator.phone.recents";
    NSString *hardwareName = @"libactivator.ipod.toggle-playback";
    NSString *hardwareSystemName = @"libactivator.system.spotlight";
    NSString *nowPlayingName = @"libactivator.audio.launch-playing-app";
    NSString *ringerName = @"libactivator.audio.reset-ringer-state";
    NSString *telephonyName = @"libactivator.phone.answer-call";
    NSString *metadataOnlyName = @"libactivator.ipod.music-controls";
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
