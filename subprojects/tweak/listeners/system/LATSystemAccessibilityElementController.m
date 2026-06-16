//
//  LATSystemAccessibilityElementController.m
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemAccessibilityElementController.h"

#import "LAActivator+Private.h"

#import <Activator/Activator.h>
#import <HBLog.h>
#import <dlfcn.h>

@interface NSObject (LATSystemAccessibilityElementPrivate)
+ (id)systemApplication;
- (NSArray *)currentApplications;
- (NSArray *)visibleElements;
- (unsigned long long)traits;
- (NSString *)label;
- (NSString *)speechInputLabel;
- (NSArray *)recognitionStrings;
- (NSArray *)userInputLabels;
- (NSString *)identifier;
- (BOOL)press;
- (BOOL)performAction:(int)action;
@end

unsigned long long const LATSystemAccessibilityBackButtonTrait = 0x08000000ULL;
int const LATSystemAccessibilityEscapeAction = 2013;

static NSString *const LATSpeechRecognitionCommandAndControlFrameworkPath =
    @"/System/Library/PrivateFrameworks/SpeechRecognitionCommandAndControl.framework/"
    @"SpeechRecognitionCommandAndControl";
static NSString *const LATAccessibilityUtilitiesFrameworkPath =
    @"/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities";
static NSTimeInterval const LATAccessibilityElementRetryDelay = 0.25;

@implementation LATSystemAccessibilityElementController

- (BOOL)performWithCurrentElementsForListenerName:(NSString *)listenerName
                                   retryUnhandled:(BOOL)retryUnhandled
                                           action:(LATSystemAccessibilityElementAction)action {
    if (!action) {
        return NO;
    }
    if (![self loadAccessibilityFrameworksForListenerName:listenerName]) {
        return NO;
    }

    BOOL shouldDelayForApplicationAccessibility =
        [self enableApplicationAccessibilityIfNeededForListenerName:listenerName];
    NSString *copiedListenerName = [listenerName copy];
    LATSystemAccessibilityElementAction copiedAction = [action copy];
    dispatch_block_t performAction = ^{
        BOOL handled = [self performAction:copiedAction listenerName:copiedListenerName];
        if (handled || !retryUnhandled) {
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           [self performAction:copiedAction listenerName:copiedListenerName];
                       });
    };

    if (NSThread.isMainThread) {
        if (shouldDelayForApplicationAccessibility) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                dispatch_get_main_queue(), performAction);
        } else {
            performAction();
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (shouldDelayForApplicationAccessibility) {
                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LATAccessibilityElementRetryDelay * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), performAction);
            } else {
                performAction();
            }
        });
    }
    return YES;
}

- (BOOL)performAction:(LATSystemAccessibilityElementAction)action listenerName:(NSString *)listenerName {
    @try {
        NSArray *elements = [self currentVisibleAccessibilityElementsForListenerName:listenerName];
        if (elements.count == 0) {
            HBLogDebug(@"No current accessibility elements for system action %@", listenerName ?: @"");
            return NO;
        }
        return action(elements);
    } @catch (NSException *exception) {
        HBLogError(@"Failed to inspect accessibility elements for system action %@: %@", listenerName ?: @"",
                   exception);
        return NO;
    }
}

- (NSArray *)currentVisibleAccessibilityElementsForListenerName:(NSString *)listenerName {
    Class elementClass = NSClassFromString(@"AXElement");
    SEL systemApplicationSelector = @selector(systemApplication);
    if (![elementClass respondsToSelector:systemApplicationSelector]) {
        HBLogError(@"AXElement is unavailable for system action %@", listenerName ?: @"");
        return @[];
    }

    id systemApplication = [elementClass systemApplication];
    NSArray *applications = nil;
    if ([systemApplication respondsToSelector:@selector(currentApplications)]) {
        applications = [systemApplication currentApplications];
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

        NSArray *visibleElements = [application visibleElements];
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

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                      matchingTrait:(unsigned long long)trait
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason {
    for (id element in elements) {
        if (![element respondsToSelector:@selector(traits)]) {
            continue;
        }

        unsigned long long traits = [element traits];
        if ((traits & trait) == 0) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility %@ for system action %@", reason ?: @"trait target",
                       listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                      matchingTitle:(NSString *)title
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason {
    if (title.length == 0) {
        return NO;
    }

    for (id element in elements) {
        if (![self element:element hasTitle:title]) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility %@ %@ for system action %@", reason ?: @"title target", title,
                       listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                     matchingTitles:(NSArray<NSString *> *)titles
                identifierHasPrefix:(NSString *)identifierPrefix
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason {
    if (titles.count == 0) {
        return NO;
    }

    for (id element in elements) {
        if (identifierPrefix.length > 0 && ![[self identifierForElement:element] hasPrefix:identifierPrefix]) {
            continue;
        }

        NSString *matchedTitle = [self firstTitleInTitles:titles matchingElement:element];
        if (matchedTitle.length == 0) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility %@ %@ for system action %@", reason ?: @"title target",
                       matchedTitle, listenerName ?: @"");
            return YES;
        }
    }
    return NO;
}

- (BOOL)pressFirstElementInElements:(NSArray *)elements
                 matchingIdentifier:(NSString *)identifier
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason {
    if (identifier.length == 0) {
        return NO;
    }

    for (id element in elements) {
        if (![[self identifierForElement:element] isEqualToString:identifier]) {
            continue;
        }

        if ([self pressElement:element]) {
            HBLogDebug(@"Pressed accessibility %@ %@ for system action %@", reason ?: @"identifier target",
                       identifier, listenerName ?: @"");
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

- (NSString *)firstTitleInTitles:(NSArray<NSString *> *)titles matchingElement:(id)element {
    for (NSString *title in titles) {
        if ([self element:element hasTitle:title]) {
            return title;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)titleCandidatesForElement:(id)element {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSArray<NSString *> *stringSelectors = @[ @"label", @"speechInputLabel" ];
    for (NSString *selectorName in stringSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![element respondsToSelector:selector]) {
            continue;
        }

        id value = [selectorName isEqualToString:@"label"] ? [element label] : [element speechInputLabel];
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

        id value =
            [selectorName isEqualToString:@"recognitionStrings"] ? [element recognitionStrings] : [element userInputLabels];
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

- (NSString *)identifierForElement:(id)element {
    SEL selector = @selector(identifier);
    if (![element respondsToSelector:selector]) {
        return nil;
    }

    id value = [element identifier];
    return [value isKindOfClass:NSString.class] ? value : nil;
}

- (BOOL)pressElement:(id)element {
    if (![element respondsToSelector:@selector(press)]) {
        return NO;
    }
    return [element press];
}

- (BOOL)performEscapeActionForElements:(NSArray *)elements listenerName:(NSString *)listenerName {
    for (id element in elements) {
        if (![element respondsToSelector:@selector(performAction:)]) {
            continue;
        }

        BOOL handled = [element performAction:LATSystemAccessibilityEscapeAction];
        if (handled) {
            HBLogDebug(@"Performed accessibility escape action for system action %@", listenerName ?: @"");
            return YES;
        }
    }
    return NO;
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
