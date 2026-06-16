//
//  main.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Activator/Activator.h>
#import <errno.h>
#import <roothide.h>
#import <string.h>
#import <sys/stat.h>
#import <unistd.h>

#import "LAActivator+Private.h"

#ifndef PACKAGE_VERSION
#define PACKAGE_VERSION "unknown"
#endif

static NSString *LAUserRebootHelperPath(void) { return jbroot(@"/usr/libexec/activator/user-reboot"); }

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
    if ([command isEqualToString:@"prerm"]) {
        return [self runPreRemovalCommand];
    }
    [self printUsage];
    return 0;
}

- (int)runCommand:(NSString *)command argument:(NSString *)argument {
    if ([command isEqualToString:@"get"]) {
        return [self runGetCommandWithKey:argument];
    }
    if ([command isEqualToString:@"activate"]) {
        [self warnIfUnknownEventName:argument];
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
        [self warnIfUnknownEventName:argument];
        LAEvent *event = [self eventWithCurrentModeNamed:argument];
        [_activator sendDeactivateEventToListeners:event];
        return [self
            exitStatusForEvent:event
                failureMessage:[NSString stringWithFormat:@"Deactivate event was not handled: %@", argument ?: @""]];
    }
#if LIBACTIVATOR_TEST_SUPPORT
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
        [self warnIfUnknownEventName:firstArgument];
        [self warnIfUnknownListenerName:secondArgument];
        return [self runSetAllModesCommandWithEventName:firstArgument listenerName:secondArgument];
    }
#endif
#if LIBACTIVATOR_TEST_SUPPORT
    if ([command isEqualToString:@"counts"]) {
        [self warnIfUnknownName:secondArgument forCountKind:firstArgument];
        return [self runCountsCommandWithKind:firstArgument name:secondArgument];
    }
#endif
    if ([command isEqualToString:@"activate"]) {
        [self warnIfUnknownEventName:firstArgument];
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
#endif

#if LIBACTIVATOR_TEST_SUPPORT
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
    NSString *helperPath = LAUserRebootHelperPath();
    const char *fileSystemPath = helperPath.fileSystemRepresentation;
    if (fileSystemPath == NULL) {
        fprintf(stderr, "Unable to resolve user-reboot helper path\n");
        return 1;
    }

    if (chown(fileSystemPath, 0, 0) != 0) {
        fprintf(stderr, "Unable to set owner for %s: %s\n", fileSystemPath, strerror(errno));
        return 1;
    }

    mode_t mode = S_ISUID | S_ISGID | S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
    if (chmod(fileSystemPath, mode) != 0) {
        fprintf(stderr, "Unable to set mode for %s: %s\n", fileSystemPath, strerror(errno));
        return 1;
    }
    return 0;
}

- (int)runPreRemovalCommand {
    return [self.activator la_setApplicationAccessibilityEnabled:NO] ? 0 : 1;
}

- (BOOL)validateListenerName:(NSString *)listenerName {
    if ([self.activator hasListenerWithName:listenerName]) {
        return YES;
    }
#if DEBUG
    [self printUnknownWarningForKind:@"listener" name:listenerName];
#else
    fprintf(stderr, "Unknown listener: %s\n", [listenerName UTF8String]);
#endif
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
- (void)warnIfUnknownEventName:(NSString *)eventName {
    if (eventName.length == 0 || [self.activator hasEventWithName:eventName]) {
        return;
    }
    [self printUnknownWarningForKind:@"event" name:eventName];
}

- (void)warnIfUnknownListenerName:(NSString *)listenerName {
    if (listenerName.length == 0 || [self.activator hasListenerWithName:listenerName]) {
        return;
    }
    [self printUnknownWarningForKind:@"listener" name:listenerName];
}

- (void)warnIfUnknownName:(NSString *)name forCountKind:(NSString *)kind {
    if ([kind isEqualToString:@"event"] || [kind isEqualToString:@"abort-event"]) {
        [self warnIfUnknownEventName:name];
        return;
    }
    if ([kind isEqualToString:@"listener"] || [kind isEqualToString:@"abort-listener"]) {
        [self warnIfUnknownListenerName:name];
    }
}

- (void)printUnknownWarningForKind:(NSString *)kind name:(NSString *)name {
    fprintf(stderr, "Warning: unknown %s: %s\n", [kind UTF8String], [name UTF8String]);
}

- (NSArray<NSString *> *)allAssignmentModes {
    return @[ LAEventModeSpringBoard, LAEventModeApplication, LAEventModeLockScreen ];
}
#endif

#if LIBACTIVATOR_TEST_SUPPORT
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

#if !DEBUG
- (void)warnIfUnknownEventName:(NSString *)eventName {
    (void)eventName;
}

- (void)warnIfUnknownName:(NSString *)name forCountKind:(NSString *)kind {
    (void)name;
    (void)kind;
}
#endif

- (void)printUsage {
    fprintf(stderr, "Activator v%s\n", PACKAGE_VERSION);
    fputs("\n", stderr);
    fputs("Usage:\n", stderr);
    fputs("  activator <command> [arguments]\n", stderr);
    fputs("\n", stderr);
    fputs("Commands:\n", stderr);
    [self printUsageCommand:@"listeners" description:@"List available listeners."];
    [self printUsageCommand:@"events" description:@"List available events."];
    [self printUsageCommand:@"modes" description:@"List available event modes."];
    [self printUsageCommand:@"current-mode" description:@"Print the active event mode."];
    [self printUsageCommand:@"current-app" description:@"Print the active application identifier."];
    [self printUsageCommand:@"get <key>" description:@"Print a compatibility preference value."];
    [self printUsageCommand:@"set <key> <value>" description:@"Set a compatibility preference value."];
    [self printUsageCommand:@"activate <event> [<listener>]" description:@"Send an activation event."];
    [self printUsageCommand:@"send <listener>" description:@"Send the default event to a listener."];
    [self printUsageCommand:@"deactivate <event>" description:@"Send a deactivation event."];
#if DEBUG || LIBACTIVATOR_TEST_SUPPORT
    fputs("\n", stderr);
    fputs("Debug commands:\n", stderr);
#if DEBUG
    [self printUsageCommand:@"set-all <event> <listener>" description:@"Assign a listener to an event in all modes."];
#endif
#if LIBACTIVATOR_TEST_SUPPORT
    [self printUsageCommand:@"counts event <event>" description:@"Print the dispatch count for an event."];
    [self printUsageCommand:@"counts listener <listener>" description:@"Print the receive count for a listener."];
    [self printUsageCommand:@"counts abort-event <event>" description:@"Print the abort count for an event."];
    [self printUsageCommand:@"counts abort-listener <listener>" description:@"Print the abort count for a listener."];
    [self printUsageCommand:@"counts events" description:@"List non-zero event dispatch counts."];
    [self printUsageCommand:@"counts listeners" description:@"List non-zero listener receive counts."];
    [self printUsageCommand:@"counts abort-events" description:@"List non-zero event abort counts."];
    [self printUsageCommand:@"counts abort-listeners" description:@"List non-zero listener abort counts."];
    [self printUsageCommand:@"counts reset" description:@"Reset all dispatch counters."];
#endif
#endif
}

- (void)printUsageCommand:(NSString *)command description:(NSString *)description {
    fprintf(stderr, "  %-36s %s\n", [command UTF8String], [description UTF8String]);
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
