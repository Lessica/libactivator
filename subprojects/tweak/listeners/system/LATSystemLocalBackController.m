//
//  LATSystemLocalBackController.m
//  libactivator
//
//  Created by Lessica on 6/16/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemLocalBackController.h"

#import "IOKitSPI.h"
#import "LAActivator+Private.h"
#import "LATHIDEventSender.h"

#import <Activator/Activator.h>
#import <HBLog.h>
#import <dlfcn.h>
#import <objc/message.h>

static NSString *const LATSpeechRecognitionCommandAndControlFrameworkPath =
    @"/System/Library/PrivateFrameworks/SpeechRecognitionCommandAndControl.framework/"
    @"SpeechRecognitionCommandAndControl";
static NSString *const LATAccessibilityUtilitiesFrameworkPath =
    @"/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities";

static NSTimeInterval const LATAccessibilityElementRetryDelay = 0.25;
static unsigned long long const LATAccessibilityBackButtonTrait = 0x08000000ULL;
static int const LATAccessibilityEscapeAction = 2013;

@interface LATSystemLocalBackController ()
@property(nonatomic, strong) LATHIDEventSender *homeButtonSender;
@end

@implementation LATSystemLocalBackController

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
    if (![self loadAccessibilityFrameworksForListenerName:listenerName]) {
        return YES;
    }
    BOOL shouldDelayForApplicationAccessibility =
        [self enableApplicationAccessibilityIfNeededForListenerName:listenerName];

    NSString *copiedListenerName = [listenerName copy];
    dispatch_block_t performLocalBack = ^{
        BOOL handled = NO;
        @try {
            handled = [self performAccessibilityLocalBackForListenerName:copiedListenerName];
        } @catch (NSException *exception) {
            HBLogError(@"Failed to perform local back for system action %@: %@", copiedListenerName ?: @"", exception);
        }

        if (handled) {
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           @try {
                               [self performAccessibilityLocalBackForListenerName:copiedListenerName];
                           } @catch (NSException *exception) {
                               HBLogError(@"Failed to retry local back for system action %@: %@",
                                          copiedListenerName ?: @"", exception);
                           }
                       });
    };
    if (NSThread.isMainThread) {
        if (shouldDelayForApplicationAccessibility) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                dispatch_get_main_queue(), performLocalBack);
        } else {
            performLocalBack();
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (shouldDelayForApplicationAccessibility) {
                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), performLocalBack);
            } else {
                performLocalBack();
            }
        });
    }
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

- (BOOL)enableApplicationAccessibilityIfNeededForListenerName:(NSString *)listenerName {
    BOOL enabled = [LAActivator.sharedInstance la_applicationAccessibilityEnabled];
    if (enabled) {
        return NO;
    }

    if (![LAActivator.sharedInstance la_setApplicationAccessibilityEnabled:YES]) {
        HBLogError(@"Failed to enable application accessibility for system action %@", listenerName ?: @"");
        return NO;
    }
    HBLogDebug(@"Enabled application accessibility for system action %@", listenerName ?: @"");
    return YES;
}

- (BOOL)performAccessibilityLocalBackForListenerName:(NSString *)listenerName {
    NSArray *elements = [self currentVisibleAccessibilityElementsForListenerName:listenerName];
    if (elements.count == 0) {
        HBLogDebug(@"No current accessibility elements for system action %@", listenerName ?: @"");
        return NO;
    }

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

- (NSArray *)currentVisibleAccessibilityElementsForListenerName:(NSString *)listenerName {
    Class elementClass = NSClassFromString(@"AXElement");
    SEL systemApplicationSelector = @selector(systemApplication);
    if (![elementClass respondsToSelector:systemApplicationSelector]) {
        HBLogError(@"AXElement is unavailable for system action %@", listenerName ?: @"");
        return @[];
    }

    id systemApplication = ((id (*)(Class, SEL))objc_msgSend)(elementClass, systemApplicationSelector);
    NSArray *applications = nil;
    if ([systemApplication respondsToSelector:@selector(currentApplications)]) {
        applications = ((id (*)(id, SEL))objc_msgSend)(systemApplication, @selector(currentApplications));
    }
    if (![applications isKindOfClass:NSArray.class]) {
        applications = @[];
    }

    NSMutableArray *elements = [NSMutableArray array];
    for (id application in applications) {
        [self addUniqueElement:application toElements:elements];
        if (![application respondsToSelector:@selector(visibleElements)]) {
            continue;
        }

        NSArray *visibleElements = ((id (*)(id, SEL))objc_msgSend)(application, @selector(visibleElements));
        if (![visibleElements isKindOfClass:NSArray.class]) {
            continue;
        }
        for (id element in visibleElements) {
            [self addUniqueElement:element toElements:elements];
        }
    }
    return elements;
}

- (void)addUniqueElement:(id)element toElements:(NSMutableArray *)elements {
    if (!element || [elements containsObject:element]) {
        return;
    }
    [elements addObject:element];
}

- (BOOL)pressFirstBackButtonElementInElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    for (id element in elements) {
        if (![element respondsToSelector:@selector(traits)]) {
            continue;
        }

        unsigned long long traits = ((unsigned long long (*)(id, SEL))objc_msgSend)(element, @selector(traits));
        if ((traits & LATAccessibilityBackButtonTrait) == 0) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility back button trait target for system action %@", listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                      matchingTitle:(NSString *)title
                       listenerName:(NSString *)listenerName {
    if (title.length == 0) {
        return NO;
    }

    for (id element in elements) {
        if (![self element:element hasTitle:title]) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility title target %@ for system action %@", title, listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (BOOL)element:(id)element hasTitle:(NSString *)title {
    for (NSString *candidate in [self titleCandidatesForElement:element]) {
        if ([candidate caseInsensitiveCompare:title] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSString *> *)titleCandidatesForElement:(id)element {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSArray<NSString *> *stringSelectors = @[ @"label", @"speechInputLabel" ];
    for (NSString *selectorName in stringSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![element respondsToSelector:selector]) {
            continue;
        }

        id value = ((id (*)(id, SEL))objc_msgSend)(element, selector);
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            [candidates addObject:value];
        }
    }

    NSArray<NSString *> *arraySelectors = @[ @"recognitionStrings", @"userInputLabels" ];
    for (NSString *selectorName in arraySelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![element respondsToSelector:selector]) {
            continue;
        }

        id value = ((id (*)(id, SEL))objc_msgSend)(element, selector);
        if (![value isKindOfClass:NSArray.class]) {
            continue;
        }
        for (id candidate in (NSArray *)value) {
            if ([candidate isKindOfClass:NSString.class] && [candidate length] > 0) {
                [candidates addObject:candidate];
            }
        }
    }
    return candidates;
}

- (BOOL)pressElement:(id)element {
    if (![element respondsToSelector:@selector(press)]) {
        return NO;
    }
    return ((BOOL (*)(id, SEL))objc_msgSend)(element, @selector(press));
}

- (BOOL)performEscapeActionForElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    for (id element in elements) {
        if (![element respondsToSelector:@selector(performAction:)]) {
            continue;
        }

        BOOL handled =
            ((BOOL (*)(id, SEL, int))objc_msgSend)(element, @selector(performAction:), LATAccessibilityEscapeAction);
        if (handled) {
            HBLogDebug(@"Performed accessibility escape action for system action %@", listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (NSString *)safariBackButtonTitle {
    Class localeUtilitiesClass = NSClassFromString(@"CACLocaleUtilities");
    SEL selector = @selector(localizedUIStringForKey:);
    if ([localeUtilitiesClass respondsToSelector:selector]) {
        id value = ((id (*)(Class, SEL, id))objc_msgSend)(localeUtilitiesClass, selector, @"SafariBackButtonLabel");
        if ([value isKindOfClass:NSString.class] && [value length] > 0) {
            return value;
        }
    }
    return @"Back";
}

- (BOOL)loadAccessibilityFrameworksForListenerName:(NSString *)listenerName {
    static dispatch_once_t sOnceToken;
    static BOOL sLoadedCommandAndControl = NO;
    static BOOL sLoadedAccessibilityUtilities = NO;
    dispatch_once(&sOnceToken, ^{
        sLoadedCommandAndControl =
            (dlopen(LATSpeechRecognitionCommandAndControlFrameworkPath.UTF8String, RTLD_LAZY) != NULL);
        sLoadedAccessibilityUtilities = (dlopen(LATAccessibilityUtilitiesFrameworkPath.UTF8String, RTLD_LAZY) != NULL);
    });

    if (!sLoadedCommandAndControl) {
        HBLogError(@"SpeechRecognitionCommandAndControl.framework is unavailable for system action %@",
                   listenerName ?: @"");
        return NO;
    }
    if (!sLoadedAccessibilityUtilities) {
        HBLogError(@"AccessibilityUtilities.framework is unavailable for system action %@", listenerName ?: @"");
        return NO;
    }
    return YES;
}

@end
