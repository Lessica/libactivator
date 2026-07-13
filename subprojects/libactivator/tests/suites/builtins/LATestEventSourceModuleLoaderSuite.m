//
//  LATestEventSourceModuleLoaderSuite.m
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestEventSourceModuleLoaderSuite.h"

#import "LAActivator+Private.h"
#import "LATEventDefinitionRegistry.h"
#import "LATEventDispatcher.h"
#import "LATEventSourceDefinitionBinding.h"
#import "LATEventSourceModule.h"
#import "LATEventSourceModuleLoader.h"
#import "LATEventSourceRegistry.h"
#import "LATestEventDefinitionProvider.h"
#import "LATestEventSource.h"

#import <Activator/Activator.h>
#import <objc/runtime.h>
#import <string.h>

@protocol LATestEventSourceModuleIngress <NSObject>
- (void)noteTestInput;
@end

@interface LATestModuleEventSource : LATestEventSource <LATestEventSourceModuleIngress>
@property(nonatomic, assign) NSUInteger inputCount;
@end

@implementation LATestModuleEventSource

- (void)noteTestInput {
    self.inputCount += 1;
}

@end

@interface LATestModuleDefinitionConsumer : LATestEventSource <LATEventSourceDefinitionConsumer>
@property(nonatomic, copy, readonly) NSSet<NSString *> *configuredEventNames;
@end

@implementation LATestModuleDefinitionConsumer {
    NSSet<NSString *> *_configuredEventNames;
}

- (void)updateConfiguredEventNames:(NSSet<NSString *> *)configuredEventNames {
    _configuredEventNames = [configuredEventNames copy];
    self.eventNames = _configuredEventNames;
}

@end

@interface LATestModuleRuntimeLockStateUpdater : NSObject <LATRuntimeLockStateUpdating>
@property(nonatomic, assign, getter=isUILocked) BOOL uiLocked;
@end

@implementation LATestModuleRuntimeLockStateUpdater

- (void)noteUILocked:(BOOL)uiLocked {
    self.uiLocked = uiLocked;
}

@end

static LATEventSourceModuleResult *LATestModuleResult(NSArray<id<LATEventSource>> *eventSources,
                                                      NSArray<id<LATEventDefinitionProvider>> *providers,
                                                      NSArray<LATEventSourceDefinitionBinding *> *bindings,
                                                      NSDictionary<NSString *, id> *services) {
    Class resultClass = NSClassFromString(@"LATEventSourceModuleResult");
    return [[resultClass alloc] initWithEventSources:eventSources
                                 definitionProviders:providers
                                  definitionBindings:bindings
                                    exportedServices:services];
}

static LATEventSourceModuleResult *LATestModuleResultWithSourceIdentifier(NSString *identifier) {
    LATestEventSource *source = [[LATestEventSource alloc] initWithIdentifier:identifier
                                                                   eventNames:[NSSet setWithObject:identifier]
                                                               interestPolicy:LATEventSourceInterestPolicyAlways];
    return LATestModuleResult(@[ source ], @[], @[], @{});
}

static LATestModuleEventSource *LATestAlphaSource;
static id LATestBetaObservedService;
static BOOL LATestUnsupportedModuleLoaded;
static LATestEventSource *LATestRollbackSourceA;
static LATestEventSource *LATestRollbackSourceB;
static LATestModuleDefinitionConsumer *LATestBindingSource;
static LATestEventDefinitionProvider *LATestBindingProvider;
static NSString *LATestBindingEventName;

@interface LATestAlphaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestAlphaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.alpha";
}

+ (NSInteger)eventSourceModulePriority {
    return 20;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestAlphaSource = [[LATestModuleEventSource alloc] initWithIdentifier:@"testing.source.alpha"
                                                                 eventNames:[NSSet setWithObject:@"testing.event.alpha"]
                                                             interestPolicy:LATEventSourceInterestPolicyAlways];
    return LATestModuleResult(
        @[ LATestAlphaSource ], @[], @[],
        @{LATEventSourceServiceKey(@protocol(LATestEventSourceModuleIngress)) : LATestAlphaSource});
}

@end

@interface LATestBetaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestBetaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.beta";
}

+ (NSInteger)eventSourceModulePriority {
    return 1;
}

+ (NSArray<NSString *> *)requiredEventSourceModuleIdentifiers {
    return @[ @"testing.alpha" ];
}

+ (LATEventSourceModuleResult *)loadWithContext:(LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestBetaObservedService = [context serviceForProtocol:@protocol(LATestEventSourceModuleIngress)];
    return LATestModuleResultWithSourceIdentifier(@"testing.source.beta");
}

@end

@interface LATestGammaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestGammaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.gamma";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (NSArray<NSString *> *)eventSourceModuleOrderingDependencies {
    return @[ @"testing.alpha" ];
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.gamma");
}

@end

@interface LATestEtaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestEtaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.eta";
}

+ (NSInteger)eventSourceModulePriority {
    return 10;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.eta");
}

@end

@interface LATestZetaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestZetaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.zeta";
}

+ (NSInteger)eventSourceModulePriority {
    return 10;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.zeta");
}

@end

@interface LATestUnsupportedModule : NSObject <LATEventSourceModule>
@end

@implementation LATestUnsupportedModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.unsupported";
}

+ (NSInteger)eventSourceModulePriority {
    return -1;
}

+ (BOOL)isSupportedWithContext:(__unused LATEventSourceModuleContext *)context {
    return NO;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestUnsupportedModuleLoaded = YES;
    return LATestModuleResultWithSourceIdentifier(@"testing.source.unsupported");
}

@end

@interface LATestDuplicateAlphaModule : NSObject <LATEventSourceModule>
@end

@implementation LATestDuplicateAlphaModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.alpha";
}

+ (NSInteger)eventSourceModulePriority {
    return 30;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.duplicate-alpha");
}

@end

@interface LATestMissingDependencyModule : NSObject <LATEventSourceModule>
@end

@implementation LATestMissingDependencyModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.missing-dependency";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (NSArray<NSString *> *)requiredEventSourceModuleIdentifiers {
    return @[ @"testing.not-present" ];
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.missing-dependency");
}

@end

@interface LATestCycleAModule : NSObject <LATEventSourceModule>
@end

@interface LATestCycleBModule : NSObject <LATEventSourceModule>
@end

@implementation LATestCycleAModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.cycle-a";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (NSArray<NSString *> *)requiredEventSourceModuleIdentifiers {
    return @[ @"testing.cycle-b" ];
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.cycle-a");
}

@end

@implementation LATestCycleBModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.cycle-b";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (NSArray<NSString *> *)requiredEventSourceModuleIdentifiers {
    return @[ @"testing.cycle-a" ];
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return LATestModuleResultWithSourceIdentifier(@"testing.source.cycle-b");
}

@end

@interface LATestInvalidResultModule : NSObject <LATEventSourceModule>
@end

@implementation LATestInvalidResultModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.invalid-result";
}

+ (NSInteger)eventSourceModulePriority {
    return 30;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    return (LATEventSourceModuleResult *)(id)[[NSObject alloc] init];
}

@end

@interface LATestRollbackAModule : NSObject <LATEventSourceModule>
@end

@implementation LATestRollbackAModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.rollback-a";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestRollbackSourceA =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.source.rollback"
                                           eventNames:[NSSet setWithObject:@"testing.event.rollback-a"]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    return LATestModuleResult(@[ LATestRollbackSourceA ], @[], @[], @{});
}

@end

@interface LATestRollbackBModule : NSObject <LATEventSourceModule>
@end

@implementation LATestRollbackBModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.rollback-b";
}

+ (NSInteger)eventSourceModulePriority {
    return 1;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestRollbackSourceB =
        [[LATestEventSource alloc] initWithIdentifier:@"testing.source.rollback"
                                           eventNames:[NSSet setWithObject:@"testing.event.rollback-b"]
                                       interestPolicy:LATEventSourceInterestPolicyAlways];
    return LATestModuleResult(@[ LATestRollbackSourceB ], @[], @[], @{});
}

@end

@interface LATestBindingModule : NSObject <LATEventSourceModule>
@end

@implementation LATestBindingModule

+ (NSString *)eventSourceModuleIdentifier {
    return @"testing.binding";
}

+ (NSInteger)eventSourceModulePriority {
    return 0;
}

+ (LATEventSourceModuleResult *)loadWithContext:(__unused LATEventSourceModuleContext *)context
                                          error:(__unused NSError **)error {
    LATestBindingSource =
        [[LATestModuleDefinitionConsumer alloc] initWithIdentifier:@"testing.source.binding"
                                                        eventNames:[NSSet set]
                                                    interestPolicy:LATEventSourceInterestPolicyAlways];
    LATestBindingProvider =
        [[LATestEventDefinitionProvider alloc] initWithIdentifier:@"testing.binding"
                                                       eventNames:[NSSet setWithObject:LATestBindingEventName]];
    Class bindingClass = NSClassFromString(@"LATEventSourceDefinitionBinding");
    LATEventSourceDefinitionBinding *binding = [[bindingClass alloc] initWithProvider:LATestBindingProvider
                                                                          eventSource:LATestBindingSource];
    return LATestModuleResult(@[ LATestBindingSource ], @[ LATestBindingProvider ], @[ binding ], @{});
}

@end

@interface LATEventSourceModuleLoader (LATestEventSourceModuleLoader)
- (nullable NSArray<Class> *)discoverModuleClassesWithError:(NSError *_Nullable *_Nullable)error;
@end

@interface LATestEventSourceModuleHarness : NSObject
@property(nonatomic, strong) LATEventSourceModuleContext *context;
@property(nonatomic, strong) LATEventSourceRegistry *sourceRegistry;
@property(nonatomic, strong) LATEventDefinitionRegistry *definitionRegistry;
@property(nonatomic, strong) LATEventSourceModuleLoader *loader;
- (instancetype)initWithActivator:(LAActivator *)activator moduleClasses:(nullable NSArray<Class> *)moduleClasses;
- (void)invalidate;
@end

@implementation LATestEventSourceModuleHarness

- (instancetype)initWithActivator:(LAActivator *)activator moduleClasses:(NSArray<Class> *)moduleClasses {
    self = [super init];
    if (self) {
        Class dispatcherClass = NSClassFromString(@"LATEventDispatcher");
        id<LATEventDispatching, LATEventModeProviding, LATEventAssignmentQuerying, LATEventDefinitionQuerying>
            dispatcher = [[dispatcherClass alloc] initWithActivator:activator];
        LATestModuleRuntimeLockStateUpdater *runtimeUpdater = [[LATestModuleRuntimeLockStateUpdater alloc] init];
        Class contextClass = NSClassFromString(@"LATEventSourceModuleContext");
        _context = [[contextClass alloc] initWithActivator:activator
                                           eventDispatcher:dispatcher
                                   runtimeLockStateUpdater:runtimeUpdater];
        Class sourceRegistryClass = NSClassFromString(@"LATEventSourceRegistry");
        _sourceRegistry = [[sourceRegistryClass alloc] initWithActivator:activator];
        Class definitionRegistryClass = NSClassFromString(@"LATEventDefinitionRegistry");
        _definitionRegistry = [[definitionRegistryClass alloc] initWithActivator:activator];
        Class loaderClass = NSClassFromString(@"LATEventSourceModuleLoader");
        _loader = [[loaderClass alloc] initWithModuleClasses:moduleClasses
                                                     context:_context
                                         eventSourceRegistry:_sourceRegistry
                                     eventDefinitionRegistry:_definitionRegistry];
    }
    return self;
}

- (void)invalidate {
    [self.definitionRegistry invalidate];
    [self.sourceRegistry invalidate];
}

@end

@implementation LATestEventSourceModuleLoaderSuite

+ (NSArray<NSString *> *)moduleIdentifiersFromClasses:(NSArray<Class> *)moduleClasses {
    NSMutableArray<NSString *> *identifiers = [[NSMutableArray alloc] initWithCapacity:moduleClasses.count];
    for (Class<LATEventSourceModule> moduleClass in moduleClasses) {
        [identifiers addObject:[moduleClass eventSourceModuleIdentifier]];
    }
    return [identifiers copy];
}

+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator {
    [recorder beginSuite:@"EventSourceModuleLoader"];

    NSArray<NSString *> *requiredClassNames = @[
        @"LATEventDispatcher",
        @"LATEventSourceModuleContext",
        @"LATEventSourceModuleResult",
        @"LATEventSourceModuleLoader",
        @"LATEventSourceDefinitionBinding",
    ];
    for (NSString *className in requiredClassNames) {
        if (!NSClassFromString(className)) {
            [recorder skip:@"module-loader-classes-available"
                    reason:[NSString stringWithFormat:@"%@ was not loaded in SpringBoard", className]];
            return;
        }
    }

    LATestEventSourceModuleHarness *discoveryHarness =
        [[LATestEventSourceModuleHarness alloc] initWithActivator:activator moduleClasses:nil];
    NSError *discoveryError = nil;
    NSArray<Class> *discoveredClasses = [discoveryHarness.loader discoverModuleClassesWithError:&discoveryError];
    const char *loaderImageName = class_getImageName(NSClassFromString(@"LATEventSourceModuleLoader"));
    BOOL discoveredOnlyLoaderImageSourceModules = discoveredClasses.count > 0 && loaderImageName != NULL &&
                                                  ![discoveredClasses containsObject:LATestAlphaModule.class];
    for (Class moduleClass in discoveredClasses) {
        const char *moduleImageName = class_getImageName(moduleClass);
        discoveredOnlyLoaderImageSourceModules =
            discoveredOnlyLoaderImageSourceModules && moduleImageName != NULL &&
            strcmp(moduleImageName, loaderImageName) == 0 &&
            class_conformsToProtocol(moduleClass, @protocol(LATEventSourceModule)) &&
            class_conformsToProtocol(moduleClass, @protocol(LATEventSource));
    }
    NSSet<NSString *> *expectedBuiltInIdentifiers = [NSSet setWithArray:@[
        @"built-in.button",
        @"built-in.edge-gesture",
        @"built-in.fingerprint-sensor",
        @"built-in.force-touch",
        @"built-in.lock-state",
        @"built-in.media",
        @"built-in.motion",
        @"built-in.multi-touch",
        @"built-in.network",
        @"built-in.power-state",
        @"built-in.springboard-icon-gesture",
        @"built-in.status-bar",
    ]];
    NSSet<NSString *> *discoveredIdentifiers =
        [NSSet setWithArray:[self moduleIdentifiersFromClasses:discoveredClasses ?: @[]]];
    [recorder expect:discoveryError == nil && discoveredOnlyLoaderImageSourceModules &&
                     [discoveredIdentifiers isEqualToSet:expectedBuiltInIdentifiers]
            caseName:@"module-discovery-uses-source-classes-in-loader-image"
              reason:@"Module discovery escaped the tweak image, used a parallel factory, or missed a built-in source"];
    [discoveryHarness invalidate];

    LATestEventSourceModuleHarness *emptyHarness = [[LATestEventSourceModuleHarness alloc] initWithActivator:activator
                                                                                               moduleClasses:@[]];
    [recorder expect:[emptyHarness.loader loadModules] && emptyHarness.loader.isLoaded &&
                     emptyHarness.loader.orderedModuleClasses.count == 0 &&
                     emptyHarness.sourceRegistry.eventSources.count == 0
            caseName:@"module-loader-preserves-explicit-empty-configuration"
              reason:@"An explicit empty module set fell back to production discovery"];
    [emptyHarness invalidate];

    LATestAlphaSource = nil;
    LATestBetaObservedService = nil;
    LATestUnsupportedModuleLoaded = NO;
    NSArray<Class> *unorderedModuleClasses = @[
        LATestBetaModule.class,
        LATestUnsupportedModule.class,
        LATestZetaModule.class,
        LATestGammaModule.class,
        LATestAlphaModule.class,
        LATestEtaModule.class,
    ];
    LATestEventSourceModuleHarness *orderingHarness =
        [[LATestEventSourceModuleHarness alloc] initWithActivator:activator moduleClasses:unorderedModuleClasses];
    BOOL orderingLoaded = [orderingHarness.loader loadModules];
    NSArray<NSString *> *orderedIdentifiers =
        [self moduleIdentifiersFromClasses:orderingHarness.loader.orderedModuleClasses];
    NSArray<NSString *> *expectedOrder =
        @[ @"testing.eta", @"testing.zeta", @"testing.alpha", @"testing.gamma", @"testing.beta" ];
    NSArray<id> *ingressSources =
        [orderingHarness.loader eventSourcesConformingToProtocol:@protocol(LATestEventSourceModuleIngress)];
    [recorder expect:orderingLoaded && [orderedIdentifiers isEqualToArray:expectedOrder] &&
                     !LATestUnsupportedModuleLoaded && LATestBetaObservedService == LATestAlphaSource &&
                     ingressSources.count == 1 && ingressSources.firstObject == LATestAlphaSource &&
                     [orderingHarness.loader serviceForProtocol:@protocol(LATestEventSourceModuleIngress)] ==
                         LATestAlphaSource &&
                     [orderingHarness.loader loadModules] && orderingHarness.sourceRegistry.eventSources.count == 5
            caseName:@"module-ordering-and-typed-resolution-are-stable"
              reason:@"Module topology, capability filtering, service injection, or typed ingress resolution diverged"];
    [orderingHarness invalidate];

    NSArray<NSArray<Class> *> *invalidGraphs = @[
        @[ LATestAlphaModule.class, LATestDuplicateAlphaModule.class ],
        @[ LATestMissingDependencyModule.class ],
        @[ LATestCycleAModule.class, LATestCycleBModule.class ],
        @[ NSObject.class ],
    ];
    BOOL invalidGraphsRejected = YES;
    for (NSArray<Class> *invalidGraph in invalidGraphs) {
        LATestEventSourceModuleHarness *harness =
            [[LATestEventSourceModuleHarness alloc] initWithActivator:activator moduleClasses:invalidGraph];
        invalidGraphsRejected = invalidGraphsRejected && ![harness.loader loadModules] && !harness.loader.isLoaded &&
                                harness.sourceRegistry.eventSources.count == 0 &&
                                harness.definitionRegistry.providers.count == 0;
        [harness invalidate];
    }
    [recorder expect:invalidGraphsRejected
            caseName:@"module-contract-errors-fail-before-registration"
              reason:@"An invalid module identifier, dependency graph, or marker contract left registered state"];

    LATestEventSourceModuleHarness *invalidResultHarness = [[LATestEventSourceModuleHarness alloc]
        initWithActivator:activator
            moduleClasses:@[ LATestAlphaModule.class, LATestInvalidResultModule.class ]];
    [recorder
          expect:![invalidResultHarness.loader loadModules] &&
                 invalidResultHarness.sourceRegistry.eventSources.count == 0 && LATestAlphaSource.invalidateCount == 1
        caseName:@"module-result-validation-cleans-earlier-construction"
          reason:@"An invalid module result retained a source built by an earlier module"];
    [invalidResultHarness invalidate];

    LATestRollbackSourceA = nil;
    LATestRollbackSourceB = nil;
    LATestEventSourceModuleHarness *rollbackHarness = [[LATestEventSourceModuleHarness alloc]
        initWithActivator:activator
            moduleClasses:@[ LATestRollbackBModule.class, LATestRollbackAModule.class ]];
    [recorder expect:![rollbackHarness.loader loadModules] && rollbackHarness.sourceRegistry.eventSources.count == 0 &&
                     LATestRollbackSourceA.invalidateCount == 1 && LATestRollbackSourceB.invalidateCount == 1
            caseName:@"module-registration-failure-rolls-back-construction"
              reason:@"A duplicate source identifier left a registered or non-invalidated module source"];
    [rollbackHarness invalidate];

    LATestBindingEventName =
        [NSString stringWithFormat:@"libactivator.test.module-binding.%@", NSUUID.UUID.UUIDString.lowercaseString];
    [activator unregisterEventDataSourceWithEventName:LATestBindingEventName];
    LATestEventSourceModuleHarness *bindingHarness =
        [[LATestEventSourceModuleHarness alloc] initWithActivator:activator
                                                    moduleClasses:@[ LATestBindingModule.class ]];
    BOOL bindingLoaded = [bindingHarness.loader loadModules];
    BOOL initialBindingApplied =
        bindingLoaded && [LATestBindingSource.configuredEventNames containsObject:LATestBindingEventName] &&
        [bindingHarness.sourceRegistry eventSourcesForEventName:LATestBindingEventName].firstObject ==
            LATestBindingSource &&
        [activator eventDataSourceForEventName:LATestBindingEventName] == LATestBindingProvider;
    BOOL returnedToDormantState =
        [LATestBindingProvider replaceEventDefinitionNames:[NSSet set]] &&
        LATestBindingSource.configuredEventNames.count == 0 &&
        [bindingHarness.sourceRegistry eventSourcesForEventName:LATestBindingEventName].count == 0 &&
        bindingHarness.sourceRegistry.eventSources.count == 1 && ![activator hasEventWithName:LATestBindingEventName];
    [recorder expect:initialBindingApplied && returnedToDormantState
            caseName:@"module-binding-supports-pure-dynamic-source-lifecycle"
              reason:@"A module binding failed to activate or return a pure dynamic source to its dormant state"];
    [bindingHarness invalidate];
    [activator unregisterEventDataSourceWithEventName:LATestBindingEventName];
}

@end
