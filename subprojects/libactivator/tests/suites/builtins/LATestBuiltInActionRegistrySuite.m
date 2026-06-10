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
    NSString *mediaName = @"libactivator.ipod.toggle-playback";
    NSString *nowPlayingName = @"libactivator.audio.launch-playing-app";
    NSString *ringerName = @"libactivator.audio.reset-ringer-state";
    NSString *phoneName = @"libactivator.phone.recents";
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
    [recorder expect:[[activator availableListenerNames] containsObject:mediaName] &&
                     [activator hasListenerWithName:mediaName]
            caseName:@"media-action-registered"
              reason:@"Built-in media action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:mediaName]
            caseName:@"media-action-seen"
              reason:@"Built-in media action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:nowPlayingName] &&
                     [activator hasListenerWithName:nowPlayingName]
            caseName:@"media-now-playing-action-registered"
              reason:@"Built-in now-playing application action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:nowPlayingName]
            caseName:@"media-now-playing-action-seen"
              reason:@"Built-in now-playing application action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:ringerName] &&
                     [activator hasListenerWithName:ringerName]
            caseName:@"ringer-action-registered"
              reason:@"Built-in ringer action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:ringerName]
            caseName:@"ringer-action-seen"
              reason:@"Built-in ringer action listener was not recorded as seen"];
    [recorder expect:[[activator availableListenerNames] containsObject:phoneName] &&
                     [activator hasListenerWithName:phoneName]
            caseName:@"phone-action-registered"
              reason:@"Built-in phone action listener was not registered"];
    [recorder expect:[activator hasSeenListenerWithName:phoneName]
            caseName:@"phone-action-seen"
              reason:@"Built-in phone action listener was not recorded as seen"];
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
