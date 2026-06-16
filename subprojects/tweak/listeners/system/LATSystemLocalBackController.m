//
//  LATSystemLocalBackController.m
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemLocalBackController.h"

#import "IOKitSPI.h"
#import "LATHIDEventSender.h"
#import "system/LATSystemAccessibilityElementController.h"

#import <Activator/Activator.h>
#import <HBLog.h>

@interface NSObject (LATCACLocaleUtilitiesPrivate)
+ (id)localizedUIStringForKey:(NSString *)key;
@end

@interface LATSystemLocalBackController ()
@property(nonatomic, strong) LATSystemAccessibilityElementController *accessibilityElementController;
@property(nonatomic, strong) LATHIDEventSender *homeButtonSender;
@end

@implementation LATSystemLocalBackController

- (instancetype)init {
    self = [super init];
    if (self) {
        _accessibilityElementController = [[LATSystemAccessibilityElementController alloc] init];
    }
    return self;
}

- (BOOL)performBackForEvent:(LAEvent *)event activator:(LAActivator *)activator listenerName:(NSString *)listenerName {
    NSString *eventMode = activator.currentEventMode ?: event.mode;
    if ([eventMode isEqualToString:LAEventModeApplication]) {
        return [self performLocalBackForListenerName:listenerName];
    }

    if ([event.name isEqualToString:LAEventNameMenuPressSingle]) {
        HBLogDebug(@"Skipping home fallback for system back action %@ from menu single press", listenerName ?: @"");
        return NO;
    }

    return [self sendHomeButtonForListenerName:listenerName];
}

- (BOOL)performLocalBackForListenerName:(NSString *)listenerName {
    NSString *copiedListenerName = [listenerName copy];
    [self.accessibilityElementController
        performWithCurrentElementsForListenerName:copiedListenerName
                                   retryUnhandled:YES
                                           action:^BOOL(NSArray *elements) {
                                               return [self performAccessibilityLocalBackWithElements:elements
                                                                                         listenerName:copiedListenerName];
                                           }];
    return YES;
}

- (BOOL)sendHomeButtonForListenerName:(NSString *)listenerName {
    if (!self.homeButtonSender) {
        self.homeButtonSender = [[LATHIDEventSender alloc] init];
    }
    return [self.homeButtonSender sendKeyboardUsagePage:kHIDPage_Consumer
                                                  usage:kHIDUsage_Csmr_Menu
                                                 reason:listenerName ?: @"libactivator.system.back"];
}

- (BOOL)performAccessibilityLocalBackWithElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    if ([self pressFirstBackButtonElementInElements:elements listenerName:listenerName]) {
        return YES;
    }

    NSString *safariBackButtonTitle = [self safariBackButtonTitle];
    if ([self pressFirstElementInElements:elements matchingTitle:safariBackButtonTitle listenerName:listenerName]) {
        return YES;
    }

    if ([self performEscapeActionForElements:elements listenerName:listenerName]) {
        return YES;
    }

    HBLogDebug(@"No accessibility local back target handled system action %@", listenerName ?: @"");
    return NO;
}

- (BOOL)pressFirstBackButtonElementInElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    return [self.accessibilityElementController pressFirstElementInElements:elements
                                                              matchingTrait:LATSystemAccessibilityBackButtonTrait
                                                               listenerName:listenerName
                                                                     reason:@"back button trait target"];
}

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                      matchingTitle:(NSString *)title
                       listenerName:(NSString *)listenerName {
    if (title.length == 0) {
        return NO;
    }

    return [self.accessibilityElementController pressFirstElementInElements:elements
                                                              matchingTitle:title
                                                               listenerName:listenerName
                                                                     reason:@"title target"];
}

- (BOOL)performEscapeActionForElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    return [self.accessibilityElementController performEscapeActionForElements:elements listenerName:listenerName];
}

- (NSString *)safariBackButtonTitle {
    Class localeUtilitiesClass = NSClassFromString(@"CACLocaleUtilities");
    SEL selector = @selector(localizedUIStringForKey:);
    if ([localeUtilitiesClass respondsToSelector:selector]) {
        id value = [localeUtilitiesClass localizedUIStringForKey:@"SafariBackButtonLabel"];
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            return value;
        }
    }
    return @"Back";
}

@end
