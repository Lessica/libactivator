//
//  LATestBuiltInDynamicApplicationListenersSuite.m
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestBuiltInDynamicApplicationListenersSuite.h"

#import "LATestEnvironment.h"
#import "LATestTestingProtocols.h"

@implementation LATestBuiltInDynamicApplicationListenersSuite

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"BuiltInDynamicApplicationListeners"];

    Class<LATestDynamicApplicationProvider> providerClass =
        (Class<LATestDynamicApplicationProvider>)NSClassFromString(@"LATApplicationListenerProvider");
    Class<LATestDynamicApplicationDescriptorFactory> descriptorClass =
        (Class<LATestDynamicApplicationDescriptorFactory>)NSClassFromString(@"LATApplicationDescriptor");
    Class listenerClass = NSClassFromString(@"LATApplicationActionListener");

    [recorder expect:providerClass != Nil
            caseName:@"dynamic-application-provider-class-available"
              reason:@"LATApplicationListenerProvider class was not loaded in SpringBoard"];
    [recorder expect:descriptorClass != Nil
            caseName:@"dynamic-application-descriptor-class-available"
              reason:@"LATApplicationDescriptor class was not loaded in SpringBoard"];
    [recorder expect:listenerClass != Nil
            caseName:@"dynamic-application-listener-class-available"
              reason:@"LATApplicationActionListener class was not loaded in SpringBoard"];
    if (!providerClass || !descriptorClass || !listenerClass) {
        return;
    }

    NSArray<id<LATestDynamicApplicationDescriptor>> *visibleDescriptors = [providerClass visibleApplicationDescriptors];
    id<LATestDynamicApplicationDescriptor> representativeDescriptor = nil;
    for (id<LATestDynamicApplicationDescriptor> descriptor in visibleDescriptors) {
        if ([descriptor isVisibleApplication] && ([descriptor isSystemApplication] || [descriptor isUserApplication])) {
            representativeDescriptor = descriptor;
            break;
        }
    }

    [recorder expect:representativeDescriptor != nil
            caseName:@"dynamic-application-visible-representative"
              reason:@"No visible System or User application was available for dynamic listener verification"];
    if (representativeDescriptor) {
        NSString *listenerName = representativeDescriptor.identifier;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
        while (![activator hasListenerWithName:listenerName] && [deadline timeIntervalSinceNow] > 0) {
            [LATestEnvironment waitAllowingMainRunLoopForTimeInterval:0.1];
            [LATestEnvironment waitForMainQueue];
        }

        [recorder expect:[activator hasListenerWithName:listenerName]
                caseName:@"dynamic-application-representative-registered"
                  reason:@"Visible application was not registered as a dynamic listener"];
        [recorder expect:![activator hasSeenListenerWithName:listenerName]
                caseName:@"dynamic-application-representative-unseen"
                  reason:@"Dynamic application listener was incorrectly marked as seen"];
        [recorder expect:[[activator localizedTitleForListenerName:listenerName]
                             isEqualToString:representativeDescriptor.displayName]
                caseName:@"dynamic-application-title"
                  reason:@"Dynamic application listener title did not come from the application descriptor"];
        [recorder expect:[[activator localizedDescriptionForListenerName:listenerName]
                             isEqualToString:[activator localizedStringForKey:@"LISTENER_DESCRIPTION_application"
                                                                        value:@"Activate application"]]
                caseName:@"dynamic-application-description"
                  reason:@"Dynamic application listener description did not match legacy semantics"];
        NSString *expectedGroup =
            [activator localizedStringForKey:[@"LISTENER_GROUP_TITLE_"
                                                 stringByAppendingString:[representativeDescriptor applicationGroup]]
                                       value:[representativeDescriptor applicationGroup]];
        [recorder expect:[[activator localizedGroupForListenerName:listenerName] isEqualToString:expectedGroup]
                caseName:@"dynamic-application-group"
                  reason:@"Dynamic application listener group was not localized from the application descriptor"];
    }

    [self runDescriptorModelTestsWithRecorder:recorder descriptorClass:descriptorClass];
}

+ (void)runDescriptorModelTestsWithRecorder:(LATestRecorder *)recorder
                            descriptorClass:(Class<LATestDynamicApplicationDescriptorFactory>)descriptorClass {
    id<LATestDynamicApplicationDescriptor> systemDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.system"
                                      displayName:@"System Example"
                                  applicationType:@"System"
                                          appTags:@[]
                                    recordAppTags:@[]
                                    bundleAppTags:@[]
                                 launchProhibited:NO];
    [recorder expect:[systemDescriptor isVisibleApplication] && [systemDescriptor isSystemApplication] &&
                     [[systemDescriptor applicationGroup] isEqualToString:@"System Applications"]
            caseName:@"dynamic-application-system-classification"
              reason:@"System application descriptor classification failed"];

    id<LATestDynamicApplicationDescriptor> userDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.user"
                                      displayName:@"User Example"
                                  applicationType:@"User"
                                          appTags:@[]
                                    recordAppTags:@[]
                                    bundleAppTags:@[]
                                 launchProhibited:NO];
    [recorder expect:[userDescriptor isVisibleApplication] && [userDescriptor isUserApplication] &&
                     [[userDescriptor applicationGroup] isEqualToString:@"User Applications"]
            caseName:@"dynamic-application-user-classification"
              reason:@"User application descriptor classification failed"];

    id<LATestDynamicApplicationDescriptor> appTagHiddenDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.hidden.app-tags"
                                      displayName:@"Hidden"
                                  applicationType:@"User"
                                          appTags:@[ @"hidden" ]
                                    recordAppTags:@[]
                                    bundleAppTags:@[]
                                 launchProhibited:NO];
    id<LATestDynamicApplicationDescriptor> recordTagHiddenDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.hidden.record-tags"
                                      displayName:@"Hidden"
                                  applicationType:@"User"
                                          appTags:@[]
                                    recordAppTags:@[ @" hidden " ]
                                    bundleAppTags:@[]
                                 launchProhibited:NO];
    id<LATestDynamicApplicationDescriptor> bundleTagHiddenDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.hidden.bundle-tags"
                                      displayName:@"Hidden"
                                  applicationType:@"User"
                                          appTags:@[]
                                    recordAppTags:@[]
                                    bundleAppTags:@[ @"hidden" ]
                                 launchProhibited:NO];
    id<LATestDynamicApplicationDescriptor> launchProhibitedDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.example.hidden.launch-prohibited"
                                      displayName:@"Hidden"
                                  applicationType:@"User"
                                          appTags:@[]
                                    recordAppTags:@[]
                                    bundleAppTags:@[]
                                 launchProhibited:YES];
    id<LATestDynamicApplicationDescriptor> webClipDescriptor =
        [descriptorClass descriptorWithIdentifier:@"com.apple.webapp.example"
                                      displayName:@"Web Clip"
                                  applicationType:@"User"
                                          appTags:@[]
                                    recordAppTags:@[]
                                    bundleAppTags:@[]
                                 launchProhibited:NO];

    [recorder
          expect:![appTagHiddenDescriptor isVisibleApplication] && ![recordTagHiddenDescriptor isVisibleApplication] &&
                 ![bundleTagHiddenDescriptor isVisibleApplication] && ![launchProhibitedDescriptor isVisibleApplication]
        caseName:@"dynamic-application-hidden-rules"
          reason:@"AltList-style hidden application filtering failed"];
    [recorder expect:[webClipDescriptor isWebClip] && ![webClipDescriptor isVisibleApplication]
            caseName:@"dynamic-application-webclip-filtered"
              reason:@"WebClip descriptor was not filtered"];
}

@end
