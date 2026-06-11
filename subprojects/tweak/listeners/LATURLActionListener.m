//
//  LATURLActionListener.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATURLActionListener.h"

#import <HBLog.h>
#import <UIKit/UIKit.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options error:(NSError **)error;
@end

@implementation LATURLActionListener

+ (NSArray<NSString *> *)supportedListenerNames {
    NSMutableArray<NSString *> *listenerNames = [@[
        @"libactivator.clock.alarm",
        @"libactivator.clock.stopwatch",
        @"libactivator.clock.timer",
        @"libactivator.clock.world-clock",
        @"libactivator.settings.about",
        @"libactivator.settings.accessibility",
        @"libactivator.settings.auto-lock",
        @"libactivator.settings.background-app-refresh",
        @"libactivator.settings.battery",
        @"libactivator.settings.bluetooth",
        @"libactivator.settings.carplay",
        @"libactivator.settings.cellular",
        @"libactivator.settings.control-center",
        @"libactivator.settings.date-time",
        @"libactivator.settings.display",
        @"libactivator.settings.do-not-disturb",
        @"libactivator.settings.facetime",
        @"libactivator.settings.game-center",
        @"libactivator.settings.general",
        @"libactivator.settings.handoff",
        @"libactivator.settings.icloud",
        @"libactivator.settings.international",
        @"libactivator.settings.keyboard",
        @"libactivator.settings.location-services",
        @"libactivator.settings.mail",
        @"libactivator.settings.managed-configuration",
        @"libactivator.settings.maps",
        @"libactivator.settings.messages",
        @"libactivator.settings.music",
        @"libactivator.settings.notes",
        @"libactivator.settings.notifications",
        @"libactivator.settings.passcode",
        @"libactivator.settings.phone",
        @"libactivator.settings.photos",
        @"libactivator.settings.privacy",
        @"libactivator.settings.reminders",
        @"libactivator.settings.safari",
        @"libactivator.settings.sounds",
        @"libactivator.settings.store",
        @"libactivator.settings.tethering",
        @"libactivator.settings.virtual-assistant",
        @"libactivator.settings.vpn",
        @"libactivator.settings.wallpaper",
        @"libactivator.settings.wifi",
    ] mutableCopy];
    [listenerNames addObjectsFromArray:[[self hardcodedURLStringsByListenerName] allKeys]];
    return listenerNames;
}

+ (BOOL)listenerNameHasRequiredMetadata:(NSString *)listenerName activator:(LAActivator *)activator {
    NSString *expectedSelector = [self hardcodedSelectorsByListenerName][listenerName ?: @""];
    if (expectedSelector.length > 0) {
        id selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
        return [selector isKindOfClass:NSString.class] && [selector isEqualToString:expectedSelector];
    }

    id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
    if ([url isKindOfClass:NSString.class] && [url length] > 0) {
        return YES;
    }
    id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
    return [urls isKindOfClass:NSArray.class] && [urls count] > 0;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName {
    if (![[self.class supportedListenerNames] containsObject:listenerName ?: @""]) {
        HBLogWarn(@"URL action %@ is not supported by this listener", listenerName ?: @"");
        return;
    }

    event.handled = YES;

    NSString *urlString = [self urlStringForListenerName:listenerName activator:activator];
    if (urlString.length == 0) {
        HBLogWarn(@"URL action %@ has no URL metadata", listenerName ?: @"");
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (url.scheme.length == 0) {
        HBLogWarn(@"URL action %@ has invalid URL metadata: %@", listenerName ?: @"", urlString);
        return;
    }

    [self openURL:url listenerName:listenerName];
}

- (NSString *)urlStringForListenerName:(NSString *)listenerName activator:(LAActivator *)activator {
    if (listenerName.length == 0) {
        return nil;
    }

    NSString *hardcodedURL = [self.class hardcodedURLStringsByListenerName][listenerName];
    if (hardcodedURL.length > 0) {
        return hardcodedURL;
    }

    id url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
    if ([url isKindOfClass:NSString.class] && [url length] > 0) {
        return url;
    }

    id urls = [activator infoDictionaryValueOfKey:@"urls" forListenerWithName:listenerName];
    return [self urlStringInURLsValue:urls];
}

- (NSString *)urlStringInURLsValue:(id)value {
    if (![value isKindOfClass:NSArray.class]) {
        return nil;
    }

    NSArray *urls = value;
    if (urls.count == 0 || ![urls[0] isKindOfClass:NSString.class] || [urls[0] length] == 0) {
        return nil;
    }

    NSString *selectedURL = urls[0];
    for (NSUInteger index = 1; index + 1 < urls.count; index += 2) {
        id thresholdValue = urls[index];
        id candidateValue = urls[index + 1];
        if (![thresholdValue respondsToSelector:@selector(doubleValue)] ||
            ![candidateValue isKindOfClass:NSString.class] || [candidateValue length] == 0) {
            continue;
        }
        if ([thresholdValue doubleValue] <= kCFCoreFoundationVersionNumber) {
            selectedURL = candidateValue;
        }
    }
    return selectedURL;
}

+ (NSDictionary<NSString *, NSString *> *)hardcodedURLStringsByListenerName {
    return @{
        @"libactivator.phone.favorites" : @"mobilephone-favorites:",
        @"libactivator.phone.recents" : @"mobilephone-recents:",
        @"libactivator.phone.contacts" : @"mobilephone-contacts:",
        @"libactivator.phone.voicemail" : @"vmshow:",
    };
}

+ (NSDictionary<NSString *, NSString *> *)hardcodedSelectorsByListenerName {
    return @{
        @"libactivator.phone.favorites" : @"showPhoneFavorites",
        @"libactivator.phone.recents" : @"showPhoneRecents",
        @"libactivator.phone.contacts" : @"showPhoneContacts",
        @"libactivator.phone.voicemail" : @"showPhoneVoicemail",
    };
}

- (BOOL)openURL:(NSURL *)url listenerName:(NSString *)listenerName {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        HBLogError(@"LSApplicationWorkspace is unavailable");
        return NO;
    }
    LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
    if (![workspace respondsToSelector:@selector(openSensitiveURL:withOptions:error:)]) {
        HBLogError(@"LSApplicationWorkspace does not support openSensitiveURL:withOptions:error:");
        return NO;
    }

    dispatch_async([self.class URLActionOpenQueue], ^{
        NSError *error = nil;
        BOOL opened = [workspace openSensitiveURL:url withOptions:@{} error:&error];
        if (!opened) {
            HBLogError(@"Failed to open URL action %@ URL %@: %@", listenerName ?: @"", url.absoluteString ?: @"",
                       error.localizedDescription ?: @"unknown error");
        }
    });

    return YES;
}

+ (dispatch_queue_t)URLActionOpenQueue {
    static dispatch_queue_t sQueue;
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        sQueue = dispatch_queue_create("libactivator.url-actions.open", DISPATCH_QUEUE_SERIAL);
    });
    return sQueue;
}

@end
