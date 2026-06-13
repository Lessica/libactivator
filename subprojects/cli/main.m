//
//  main.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Activator/Activator.h>

@interface LAActivator (LegacyCompatibility)
- (nullable id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(nullable id)value forPreference:(NSString *)preference;
- (NSDictionary<NSString *, NSNumber *> *)la_eventDispatchCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_listenerReceiveCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_eventAbortCounts;
- (NSDictionary<NSString *, NSNumber *> *)la_listenerAbortCounts;
- (void)la_resetDispatchCounts;
@end

@interface LACommandLineTool : NSObject
- (instancetype)initWithArgc:(int)argc argv:(char *[])argv;
- (int)run;
@end

@interface LACommandLineTool ()
@property(nonatomic, copy) NSArray<NSString *> *arguments;
@property(nonatomic, strong) LAActivator *activator;
@end

@implementation LACommandLineTool

- (instancetype)initWithArgc:(int)argc argv:(char *[])argv {
    self = [super init];
    if (self) {
        NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithCapacity:(NSUInteger)argc];
        for (int index = 0; index < argc; index++) {
            [arguments addObject:[NSString stringWithUTF8String:argv[index] ?: ""]];
        }
        _arguments = [arguments copy];
        _activator = LAActivator.sharedInstance;
    }
    return self;
}

- (int)run {
    if (self.arguments.count <= 1) {
        [self printUsage];
        return 0;
    }

    NSString *command = [self argumentAtIndex:1];
    if (self.arguments.count == 2) {
        return [self runCommandWithoutArguments:command];
    }
    if (self.arguments.count == 3) {
        return [self runCommand:command argument:[self argumentAtIndex:2]];
    }
    if (self.arguments.count == 4) {
        return [self runCommand:command firstArgument:[self argumentAtIndex:2] secondArgument:[self argumentAtIndex:3]];
    }
    [self printUsage];
    return 0;
}

- (int)runCommandWithoutArguments:(NSString *)command {
    if ([command isEqualToString:@"listeners"]) {
        [self printObjects:self.activator.availableListenerNames];
        return 0;
    }
    if ([command isEqualToString:@"events"]) {
        [self printObjects:self.activator.availableEventNames];
        return 0;
    }
    if ([command isEqualToString:@"modes"]) {
        [self printObjects:self.activator.availableEventModes];
        return 0;
    }
    if ([command isEqualToString:@"current-mode"]) {
        [self printObject:self.activator.currentEventMode];
        return 0;
    }
    if ([command isEqualToString:@"current-app"]) {
        NSString *displayIdentifier = self.activator.displayIdentifierForCurrentApplication;
        if (displayIdentifier.length > 0) {
            [self printObject:displayIdentifier];
        }
        return 0;
    }
    if ([command isEqualToString:@"postinst"]) {
        return [self runPostInstallCommand];
    }
    [self printUsage];
    return 0;
}

- (int)runCommand:(NSString *)command argument:(NSString *)argument {
    if ([command isEqualToString:@"get"]) {
        return [self runGetCommandWithKey:argument];
    }
    if ([command isEqualToString:@"activate"]) {
        LAEvent *event = [self eventWithCurrentModeNamed:argument];
        [_activator sendEventToListener:event];
        return [self exitStatusForEvent:event
                         failureMessage:[NSString stringWithFormat:@"Event was not handled: %@", argument ?: @""]];
    }
    if ([command isEqualToString:@"send"]) {
        if (![self validateListenerName:argument]) {
            return 1;
        }
        LAEvent *event = [self eventWithCurrentModeNamed:@"libactivator"];
        [_activator sendEvent:event toListenerWithName:argument];
        return
            [self exitStatusForEvent:event
                      failureMessage:[NSString stringWithFormat:@"Listener did not handle event: %@", argument ?: @""]];
    }
    if ([command isEqualToString:@"deactivate"]) {
        LAEvent *event = [self eventWithCurrentModeNamed:argument];
        [_activator sendDeactivateEventToListeners:event];
        return [self
            exitStatusForEvent:event
                failureMessage:[NSString stringWithFormat:@"Deactivate event was not handled: %@", argument ?: @""]];
    }
#if DEBUG
    if ([command isEqualToString:@"counts"]) {
        return [self runCountsCommandWithArgument:argument];
    }
#endif

    [self printUsage];
    return 0;
}

- (int)runCommand:(NSString *)command
     firstArgument:(NSString *)firstArgument
    secondArgument:(NSString *)secondArgument {
    if ([command isEqualToString:@"set"]) {
        return [self runSetCommandWithKey:firstArgument value:secondArgument];
    }
#if DEBUG
    if ([command isEqualToString:@"set-all"]) {
        return [self runSetAllModesCommandWithEventName:firstArgument listenerName:secondArgument];
    }
    if ([command isEqualToString:@"counts"]) {
        return [self runCountsCommandWithKind:firstArgument name:secondArgument];
    }
#endif
    if ([command isEqualToString:@"activate"]) {
        if (![self validateListenerName:secondArgument]) {
            return 1;
        }
        LAEvent *event = [self eventWithCurrentModeNamed:firstArgument];
        [_activator sendEvent:event toListenerWithName:secondArgument];
        return [self exitStatusForEvent:event
                         failureMessage:[NSString stringWithFormat:@"Listener did not handle event: %@ for %@",
                                                                   secondArgument ?: @"", firstArgument ?: @""]];
    }

    [self printUsage];
    return 0;
}

- (int)runGetCommandWithKey:(NSString *)key {
    id value = [self.activator _getObjectForPreference:key];
    if (value) {
        [self printObject:value];
    }
    return 0;
}

- (int)runSetCommandWithKey:(NSString *)key value:(NSString *)value {
    [self.activator _setObject:value forPreference:key];
    return 0;
}

#if DEBUG
- (int)runSetAllModesCommandWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName {
    for (NSString *eventMode in [self allAssignmentModes]) {
        NSString *key = [NSString stringWithFormat:@"LAEventListener(%@)-%@", eventMode, eventName];
        [self.activator _setObject:listenerName forPreference:key];
    }
    return 0;
}

- (int)runCountsCommandWithArgument:(NSString *)argument {
    if ([argument isEqualToString:@"events"]) {
        [self printCounts:self.activator.la_eventDispatchCounts];
        return 0;
    }
    if ([argument isEqualToString:@"listeners"]) {
        [self printCounts:self.activator.la_listenerReceiveCounts];
        return 0;
    }
    if ([argument isEqualToString:@"abort-events"]) {
        [self printCounts:self.activator.la_eventAbortCounts];
        return 0;
    }
    if ([argument isEqualToString:@"abort-listeners"]) {
        [self printCounts:self.activator.la_listenerAbortCounts];
        return 0;
    }
    if ([argument isEqualToString:@"reset"]) {
        [self.activator la_resetDispatchCounts];
        return 0;
    }
    [self printUsage];
    return 0;
}

- (int)runCountsCommandWithKind:(NSString *)kind name:(NSString *)name {
    if ([kind isEqualToString:@"event"]) {
        [self printCountForName:name counts:self.activator.la_eventDispatchCounts];
        return 0;
    }
    if ([kind isEqualToString:@"listener"]) {
        [self printCountForName:name counts:self.activator.la_listenerReceiveCounts];
        return 0;
    }
    if ([kind isEqualToString:@"abort-event"]) {
        [self printCountForName:name counts:self.activator.la_eventAbortCounts];
        return 0;
    }
    if ([kind isEqualToString:@"abort-listener"]) {
        [self printCountForName:name counts:self.activator.la_listenerAbortCounts];
        return 0;
    }
    [self printUsage];
    return 0;
}
#endif

- (int)runPostInstallCommand {
    return 0;
}

- (BOOL)validateListenerName:(NSString *)listenerName {
    if ([self.activator hasListenerWithName:listenerName]) {
        return YES;
    }
    fprintf(stderr, "Unknown listener: %s\n", [listenerName UTF8String]);
    return NO;
}

- (LAEvent *)eventWithCurrentModeNamed:(NSString *)eventName {
    return [LAEvent eventWithName:eventName mode:self.activator.currentEventMode];
}

- (int)exitStatusForEvent:(LAEvent *)event failureMessage:(NSString *)failureMessage {
    if (event.handled) {
        return 0;
    }
    fprintf(stderr, "%s\n", [failureMessage UTF8String]);
    return 1;
}

- (NSString *)argumentAtIndex:(NSUInteger)index {
    return index < self.arguments.count ? self.arguments[index] : @"";
}

#if DEBUG
- (NSArray<NSString *> *)allAssignmentModes {
    return @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
}

- (void)printCounts:(NSDictionary<NSString *, NSNumber *> *)counts {
    NSArray<NSString *> *keys = [counts.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        NSNumber *count = counts[key];
        if (![count isKindOfClass:NSNumber.class]) {
            continue;
        }
        if ([count unsignedLongLongValue] == 0) {
            continue;
        }
        printf("%llu\t%s\n", [count unsignedLongLongValue], [key UTF8String]);
    }
}

- (void)printCountForName:(NSString *)name counts:(NSDictionary<NSString *, NSNumber *> *)counts {
    NSNumber *count = counts[name ?: @""];
    printf("%llu\n", [count isKindOfClass:NSNumber.class] ? [count unsignedLongLongValue] : 0);
}
#endif

- (void)printUsage {
    fprintf(stderr, "Activator version: %ld\n", (long)self.activator.version);
    fputs("Usage:\n", stderr);
    fputs("\tactivator listeners\n", stderr);
    fputs("\tactivator events\n", stderr);
    fputs("\tactivator modes\n", stderr);
    fputs("\tactivator current-mode\n", stderr);
    fputs("\tactivator current-app\n", stderr);
    fputs("\tactivator get <key>\n", stderr);
    fputs("\tactivator set <key> <value>\n", stderr);
#if DEBUG
    fputs("\tactivator set-all <event> <listener>\n", stderr);
    fputs("\tactivator counts event <event>\n", stderr);
    fputs("\tactivator counts listener <listener>\n", stderr);
    fputs("\tactivator counts abort-event <event>\n", stderr);
    fputs("\tactivator counts abort-listener <listener>\n", stderr);
    fputs("\tactivator counts events\n", stderr);
    fputs("\tactivator counts listeners\n", stderr);
    fputs("\tactivator counts abort-events\n", stderr);
    fputs("\tactivator counts abort-listeners\n", stderr);
    fputs("\tactivator counts reset\n", stderr);
#endif
    fputs("\tactivator activate <event> [<listener>]\n", stderr);
    fputs("\tactivator send <listener>\n", stderr);
    fputs("\tactivator deactivate <event>\n", stderr);
}

- (void)printObject:(id)object {
    NSString *description = [[object description] length] > 0 ? [object description] : @"";
    printf("%s\n", [description UTF8String]);
}

- (void)printObjects:(NSArray *)objects {
    for (id object in objects) {
        [self printObject:object];
    }
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        LACommandLineTool *tool = [[LACommandLineTool alloc] initWithArgc:argc argv:argv];
        return [tool run];
    }
}
