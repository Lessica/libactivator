//
//  LATVolumeHUDTapEventSource.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATVolumeHUDTapEventSource.h"

#import "LAQueueAssertions.h"

#import <Activator/Activator.h>
#import <HBLog.h>
#import <objc/runtime.h>

@interface LATVolumeHUDTapEventSource ()

@property(nonatomic, strong) id<LATEventDispatching> eventDispatcher;
@property(nonatomic, strong) id<LATEventModeProviding> modeProvider;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, assign, getter=isInvalidated) BOOL invalidated;
@property(nonatomic, strong) NSHashTable<UIView *> *knownSliderContainerViews;
@property(nonatomic, strong) NSHashTable<UITapGestureRecognizer *> *installedRecognizers;

@end

@implementation LATVolumeHUDTapEventSource

#pragma mark - LATEventSource

- (instancetype)initWithEventSourceContext:(LATEventSourceContext *)context {
    Class controllerClass = NSClassFromString(@"SBElasticVolumeViewController");
    if (!controllerClass || ![controllerClass instancesRespondToSelector:@selector(viewDidLoad)] ||
        !class_getInstanceVariable(controllerClass, "_sliderContainerView")) {
        return nil;
    }
    return [self initWithEventDispatcher:context.eventDispatcher modeProvider:context.eventDispatcher];
}

- (NSString *)eventSourceIdentifier {
    return @"volume-hud-tap";
}

- (NSSet<NSString *> *)eventNames {
    return [NSSet setWithObject:LAEventNameVolumeDisplayTap];
}

- (LATEventSourceInterestPolicy)interestPolicy {
    return LATEventSourceInterestPolicyAlways;
}

- (instancetype)initWithEventDispatcher:(id<LATEventDispatching>)eventDispatcher
                           modeProvider:(id<LATEventModeProviding>)modeProvider {
    NSParameterAssert(eventDispatcher);
    NSParameterAssert(modeProvider);

    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _modeProvider = modeProvider;
        _knownSliderContainerViews = [NSHashTable weakObjectsHashTable];
        _installedRecognizers = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)start {
    LAAssertMainQueue();
    if (self.isStarted || self.isInvalidated) {
        return;
    }
    self.started = YES;
    [self installInKnownSliderContainerViews];
}

- (void)invalidate {
    LAAssertMainQueue();
    if (self.isInvalidated) {
        return;
    }

    self.invalidated = YES;
    self.started = NO;
    [self removeInstalledRecognizers];
    [self.knownSliderContainerViews removeAllObjects];
}

#pragma mark - Gesture Recognizer Attachment

- (void)noteVolumeHUDSliderContainerViewDidLoad:(UIView *)sliderContainerView {
    LAAssertMainQueue();
    if (!sliderContainerView || self.isInvalidated) {
        return;
    }

    [self.knownSliderContainerViews addObject:sliderContainerView];
    if (!self.isStarted) {
        return;
    }

    for (UITapGestureRecognizer *recognizer in self.installedRecognizers.allObjects) {
        if (recognizer.view == sliderContainerView) {
            return;
        }
    }

    UITapGestureRecognizer *recognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(volumeHUDTapRecognized:)];
    recognizer.cancelsTouchesInView = NO;
    recognizer.delaysTouchesBegan = NO;
    recognizer.delaysTouchesEnded = NO;
    [sliderContainerView addGestureRecognizer:recognizer];
    [self.installedRecognizers addObject:recognizer];
}

- (void)installInKnownSliderContainerViews {
    LAAssertMainQueue();
    for (UIView *sliderContainerView in self.knownSliderContainerViews.allObjects) {
        [self noteVolumeHUDSliderContainerViewDidLoad:sliderContainerView];
    }
}

- (void)removeInstalledRecognizers {
    LAAssertMainQueue();
    for (UITapGestureRecognizer *recognizer in self.installedRecognizers.allObjects) {
        [recognizer.view removeGestureRecognizer:recognizer];
    }
    [self.installedRecognizers removeAllObjects];
}

#pragma mark - Recognition

- (void)volumeHUDTapRecognized:(UITapGestureRecognizer *)recognizer {
    LAAssertMainQueue();
    [self handleTapState:recognizer.state];
}

- (BOOL)handleTapState:(UIGestureRecognizerState)state {
    LAAssertMainQueue();
    if (!self.isStarted || self.isInvalidated || state != UIGestureRecognizerStateEnded) {
        return NO;
    }

    NSString *eventMode = self.modeProvider.currentEventMode;
    if (eventMode.length == 0) {
        eventMode = LAEventModeSpringBoard;
    }

    LAEvent *event = [LAEvent eventWithName:LAEventNameVolumeDisplayTap mode:eventMode];
    [self.eventDispatcher dispatchEvent:event];
    HBLogInfo(@"Dispatched Volume HUD tap event mode=%@", eventMode);
    return YES;
}

#if DEBUG
#pragma mark - Testing Hooks

- (BOOL)la_testingHandleTapState:(UIGestureRecognizerState)state {
    return [self handleTapState:state];
}

- (NSUInteger)la_testingKnownSliderContainerViewCount {
    return self.knownSliderContainerViews.count;
}

- (BOOL)la_testingIsInstalledInSliderContainerView:(UIView *)sliderContainerView {
    for (UITapGestureRecognizer *recognizer in self.installedRecognizers.allObjects) {
        if (recognizer.view == sliderContainerView) {
            return YES;
        }
    }
    return NO;
}
#endif

@end
