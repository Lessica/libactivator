//
//  LACommandLineTool.m
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LACommandLineTool.h"

#import <Activator/Activator.h>
#import <errno.h>
#import <roothide.h>
#import <string.h>
#import <sys/stat.h>
#import <sysexits.h>
#import <unistd.h>

#import "LAActivator+Private.h"

#ifndef PACKAGE_VERSION
#define PACKAGE_VERSION "unknown"
#endif

@interface LACommandLineTool ()
@property(nonatomic, copy) NSArray<NSString *> *arguments;
@property(nonatomic, strong) LAActivator *activator;
@property(nonatomic, assign) int invalidArgumentIndex;
@end

@implementation LACommandLineTool

- (instancetype)initWithArgc:(int)argc argv:(char *_Nonnull const *_Nonnull)argv {
    self = [super init];
    if (self) {
        _invalidArgumentIndex = -1;
        NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithCapacity:(NSUInteger)argc];
        for (int index = 0; index < argc; index++) {
            NSString *argument = [NSString stringWithUTF8String:argv[index] ?: ""];
            if (!argument) {
                _invalidArgumentIndex = index;
                break;
            }
            [arguments addObject:argument];
        }
        _arguments = [arguments copy];
        _activator = LAActivator.sharedInstance;
    }
    return self;
}

- (int)run {
    if (self.invalidArgumentIndex >= 0) {
        fprintf(stderr, "Invalid UTF-8 in argument %d\n", self.invalidArgumentIndex);
        return EX_DATAERR;
    }
    if (self.arguments.count <= 1) {
        [self printUsage];
        return 0;
    }

    NSString *command = self.arguments[1];
#if DEBUG
    if ([command isEqualToString:@"debug"]) {
        if (self.arguments.count == 2) {
            [self printDebugUsage];
            return 0;
        }
        if (![self.activator la_isSpringBoardServiceReachable]) {
            fputs("Unable to connect to the SpringBoard Activator service\n", stderr);
            return 1;
        }
        return [self
            runDebugCommandWithArguments:[self.arguments subarrayWithRange:NSMakeRange(2, self.arguments.count - 2)]];
    }
#endif
    if ([self commandRequiresSpringBoardService:command argumentCount:self.arguments.count] &&
        ![self.activator la_isSpringBoardServiceReachable]) {
        fputs("Unable to connect to the SpringBoard Activator service\n", stderr);
        return 1;
    }

    if (self.arguments.count == 2) {
        return [self runCommandWithoutArguments:command];
    }
    if (self.arguments.count == 3) {
        return [self runCommand:command argument:self.arguments[2]];
    }
    if (self.arguments.count == 4) {
        return [self runCommand:command firstArgument:self.arguments[2] secondArgument:self.arguments[3]];
    }
    [self printUsage];
    return 0;
}

- (BOOL)commandRequiresSpringBoardService:(NSString *)command argumentCount:(NSUInteger)argumentCount {
    if (argumentCount == 2) {
        return
            [@[ @"listeners", @"events", @"modes", @"current-mode", @"current-app", @"prerm" ] containsObject:command];
    }
    if (argumentCount == 3) {
        return [@[ @"get", @"activate", @"send", @"deactivate" ] containsObject:command];
    }
    if (argumentCount == 4) {
        return [@[ @"set", @"activate" ] containsObject:command];
    }
    return NO;
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

    [self printUsage];
    return 0;
}

- (int)runCommand:(NSString *)command
     firstArgument:(NSString *)firstArgument
    secondArgument:(NSString *)secondArgument {
    if ([command isEqualToString:@"set"]) {
        return [self runSetCommandWithKey:firstArgument value:secondArgument];
    }
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
- (int)runDebugCommandWithArguments:(NSArray<NSString *> *)arguments {
    NSString *command = arguments.firstObject;
    if ([command isEqualToString:@"assignments"]) {
        return [self runDebugAssignmentsCommandWithArguments:arguments];
    }
    if ([command isEqualToString:@"stats"]) {
        return [self runDebugStatisticsCommandWithArguments:arguments];
    }
    [self printDebugUsage];
    return EX_USAGE;
}

- (int)runDebugAssignmentsCommandWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count == 2 && [arguments[1] isEqualToString:@"list"]) {
        [self printAssignmentSnapshot:self.activator.la_debugAssignmentSnapshot];
        return 0;
    }
    if (arguments.count == 4 && [arguments[1] isEqualToString:@"get"]) {
        [self warnIfUnknownEventName:arguments[2]];
        return [self printAssignmentsForEventName:arguments[2] modeArgument:arguments[3]] ? 0 : EX_USAGE;
    }
    if (arguments.count >= 5 && [arguments[1] isEqualToString:@"set"]) {
        NSString *eventName = arguments[2];
        LAEvent *event = [self assignmentEventWithName:eventName modeArgument:arguments[3]];
        if (!event) {
            return EX_USAGE;
        }
        [self warnIfUnknownEventName:eventName];
        NSArray<NSString *> *listenerNames = [arguments subarrayWithRange:NSMakeRange(4, arguments.count - 4)];
        for (NSString *listenerName in listenerNames) {
            [self warnIfUnknownListenerName:listenerName];
        }
        [self.activator assignEvent:event toListenersWithNames:listenerNames];
        [self printAssignmentsForEventName:eventName modeArgument:arguments[3]];
        return 0;
    }
    if (arguments.count == 5 && ([arguments[1] isEqualToString:@"add"] || [arguments[1] isEqualToString:@"remove"])) {
        NSString *eventName = arguments[2];
        NSString *listenerName = arguments[4];
        LAEvent *event = [self assignmentEventWithName:eventName modeArgument:arguments[3]];
        if (!event) {
            return EX_USAGE;
        }
        [self warnIfUnknownEventName:eventName];
        [self warnIfUnknownListenerName:listenerName];
        if ([arguments[1] isEqualToString:@"add"]) {
            [self.activator addListenerAssignment:listenerName toEvent:event];
        } else {
            [self.activator removeListenerAssignment:listenerName fromEvent:event];
        }
        [self printAssignmentsForEventName:eventName modeArgument:arguments[3]];
        return 0;
    }
    if (arguments.count == 4 && [arguments[1] isEqualToString:@"clear"]) {
        NSString *eventName = arguments[2];
        LAEvent *event = [self assignmentEventWithName:eventName modeArgument:arguments[3]];
        if (!event) {
            return EX_USAGE;
        }
        [self warnIfUnknownEventName:eventName];
        [self.activator unassignEvent:event];
        [self printAssignmentsForEventName:eventName modeArgument:arguments[3]];
        return 0;
    }
    if (arguments.count == 2 && [arguments[1] isEqualToString:@"reset"]) {
        BOOL changed = [self.activator la_debugResetAssignmentsAndNotifyIfChanged];
        printf("assignments-reset\t%s\n", changed ? "changed" : "unchanged");
        return 0;
    }
    [self printDebugUsage];
    return EX_USAGE;
}

- (LAEvent *)assignmentEventWithName:(NSString *)eventName modeArgument:(NSString *)modeArgument {
    if (eventName.length == 0) {
        fputs("Assignment event name must not be empty\n", stderr);
        return nil;
    }
    if ([modeArgument isEqualToString:@"all"]) {
        return [LAEvent eventWithName:eventName mode:nil];
    }

    NSString *eventMode = modeArgument;
    if ([modeArgument isEqualToString:@"current"]) {
        eventMode = self.activator.currentEventMode;
    }
    if (eventMode.length == 0 || ![self.activator.availableEventModes containsObject:eventMode]) {
        fprintf(stderr, "Unknown assignment mode: %s\n", [modeArgument UTF8String]);
        return nil;
    }
    return [LAEvent eventWithName:eventName mode:eventMode];
}

- (BOOL)printAssignmentsForEventName:(NSString *)eventName modeArgument:(NSString *)modeArgument {
    LAEvent *event = [self assignmentEventWithName:eventName modeArgument:modeArgument];
    if (!event) {
        return NO;
    }

    NSDictionary<NSString *, NSArray<NSString *> *> *eventAssignments =
        self.activator.la_debugAssignmentSnapshot[eventName];
    NSArray<NSString *> *eventModes =
        event.mode ? @[ event.mode ] : [eventAssignments.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *eventMode in eventModes) {
        NSArray<NSString *> *listenerNames = [eventAssignments[eventMode] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *listenerName in listenerNames) {
            NSString *displayMode = eventMode.length > 0 ? eventMode : @"<default>";
            printf("%s\t%s\t%s\n", [displayMode UTF8String], [eventName UTF8String], [listenerName UTF8String]);
        }
    }
    return YES;
}

- (void)printAssignmentSnapshot:
    (NSDictionary<NSString *, NSDictionary<NSString *, NSArray<NSString *> *> *> *)snapshot {
    NSArray<NSString *> *eventNames = [snapshot.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *eventName in eventNames) {
        NSDictionary<NSString *, NSArray<NSString *> *> *eventAssignments = snapshot[eventName];
        NSArray<NSString *> *eventModes = [eventAssignments.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *eventMode in eventModes) {
            NSArray<NSString *> *listenerNames =
                [eventAssignments[eventMode] sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *listenerName in listenerNames) {
                NSString *displayMode = eventMode.length > 0 ? eventMode : @"<default>";
                printf("%s\t%s\t%s\n", [displayMode UTF8String], [eventName UTF8String], [listenerName UTF8String]);
            }
        }
    }
}

- (int)runDebugStatisticsCommandWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count == 1 || (arguments.count == 2 && [arguments[1] isEqualToString:@"summary"])) {
        [self printDebugStatisticsSummary];
        return 0;
    }
    if (arguments.count == 2 && [arguments[1] isEqualToString:@"reset"]) {
        [self.activator la_resetDispatchCounts];
        [self printDebugStatisticsSummary];
        return 0;
    }
    if (arguments.count == 2) {
        NSDictionary<NSString *, NSNumber *> *counts = [self debugStatisticsCountsForKind:arguments[1]];
        if (!counts) {
            [self printDebugUsage];
            return EX_USAGE;
        }
        [self printCounts:counts];
        return 0;
    }
    if (arguments.count == 3) {
        NSString *kind = arguments[1];
        NSString *name = arguments[2];
        if (![@[ @"event", @"listener", @"abort-event", @"abort-listener" ] containsObject:kind]) {
            [self printDebugUsage];
            return EX_USAGE;
        }
        NSDictionary<NSString *, NSNumber *> *counts = [self debugStatisticsCountsForKind:kind];
        if (!counts) {
            [self printDebugUsage];
            return EX_USAGE;
        }
        if ([kind isEqualToString:@"event"] || [kind isEqualToString:@"abort-event"]) {
            [self warnIfUnknownEventName:name];
        } else {
            [self warnIfUnknownListenerName:name];
        }
        printf("%llu\n", [counts[name] unsignedLongLongValue]);
        return 0;
    }
    [self printDebugUsage];
    return EX_USAGE;
}

- (NSDictionary<NSString *, NSNumber *> *)debugStatisticsCountsForKind:(NSString *)kind {
    if ([kind isEqualToString:@"events"] || [kind isEqualToString:@"event"]) {
        return self.activator.la_eventDispatchCounts;
    }
    if ([kind isEqualToString:@"listeners"] || [kind isEqualToString:@"listener"]) {
        return self.activator.la_listenerReceiveCounts;
    }
    if ([kind isEqualToString:@"abort-events"] || [kind isEqualToString:@"abort-event"]) {
        return self.activator.la_eventAbortCounts;
    }
    if ([kind isEqualToString:@"abort-listeners"] || [kind isEqualToString:@"abort-listener"]) {
        return self.activator.la_listenerAbortCounts;
    }
    return nil;
}

- (void)printDebugStatisticsSummary {
    NSArray<NSString *> *eventNames = self.activator.availableEventNames;
    NSArray<NSString *> *eventModes = self.activator.availableEventModes;
    NSDictionary<NSString *, NSDictionary<NSString *, NSArray<NSString *> *> *> *assignmentSnapshot =
        self.activator.la_debugAssignmentSnapshot;
    NSUInteger assignedEventCount = assignmentSnapshot.count;
    NSUInteger assignmentSlotCount = 0;
    NSUInteger assignmentBindingCount = 0;
    for (NSDictionary<NSString *, NSArray<NSString *> *> *eventAssignments in assignmentSnapshot.allValues) {
        assignmentSlotCount += eventAssignments.count;
        for (NSArray<NSString *> *listenerNames in eventAssignments.allValues) {
            assignmentBindingCount += listenerNames.count;
        }
    }

    NSDictionary<NSString *, NSNumber *> *eventDispatchCounts = self.activator.la_eventDispatchCounts;
    NSDictionary<NSString *, NSNumber *> *listenerReceiveCounts = self.activator.la_listenerReceiveCounts;
    NSDictionary<NSString *, NSNumber *> *eventAbortCounts = self.activator.la_eventAbortCounts;
    NSDictionary<NSString *, NSNumber *> *listenerAbortCounts = self.activator.la_listenerAbortCounts;
    unsigned long long eventDispatchTotal = 0;
    unsigned long long listenerReceiveTotal = 0;
    unsigned long long eventAbortTotal = 0;
    unsigned long long listenerAbortTotal = 0;
    for (NSNumber *count in eventDispatchCounts.allValues) {
        eventDispatchTotal += count.unsignedLongLongValue;
    }
    for (NSNumber *count in listenerReceiveCounts.allValues) {
        listenerReceiveTotal += count.unsignedLongLongValue;
    }
    for (NSNumber *count in eventAbortCounts.allValues) {
        eventAbortTotal += count.unsignedLongLongValue;
    }
    for (NSNumber *count in listenerAbortCounts.allValues) {
        listenerAbortTotal += count.unsignedLongLongValue;
    }

    NSString *currentApplication = self.activator.displayIdentifierForCurrentApplication ?: @"-";
    printf("current-mode\t%s\n", [self.activator.currentEventMode UTF8String]);
    printf("current-profile\t%s\n", [self.activator.currentProfileName UTF8String]);
    printf("current-app\t%s\n", [currentApplication UTF8String]);
    printf("available-events\t%lu\n", (unsigned long)eventNames.count);
    printf("available-listeners\t%lu\n", (unsigned long)self.activator.availableListenerNames.count);
    printf("available-modes\t%lu\n", (unsigned long)eventModes.count);
    printf("available-profiles\t%lu\n", (unsigned long)self.activator.availableProfileNames.count);
    printf("assigned-events\t%lu\n", (unsigned long)assignedEventCount);
    printf("assignment-slots\t%lu\n", (unsigned long)assignmentSlotCount);
    printf("assignment-bindings\t%lu\n", (unsigned long)assignmentBindingCount);
    printf("event-dispatches\t%llu\n", eventDispatchTotal);
    printf("listener-receives\t%llu\n", listenerReceiveTotal);
    printf("event-aborts\t%llu\n", eventAbortTotal);
    printf("listener-aborts\t%llu\n", listenerAbortTotal);
}

- (void)printCounts:(NSDictionary<NSString *, NSNumber *> *)counts {
    NSArray<NSString *> *names = [counts.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *name in names) {
        unsigned long long count = [counts[name] unsignedLongLongValue];
        if (count > 0) {
            printf("%llu\t%s\n", count, [name UTF8String]);
        }
    }
}
#endif

- (int)runPostInstallCommand {
    NSString *helperPath = jbroot(@"/usr/libexec/activator/user-reboot");
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

- (void)printUnknownWarningForKind:(NSString *)kind name:(NSString *)name {
    fprintf(stderr, "Warning: unknown %s: %s\n", [kind UTF8String], [name UTF8String]);
}
#endif

#if !DEBUG
- (void)warnIfUnknownEventName:(NSString *)eventName {
    (void)eventName;
}
#endif

- (void)printUsage {
    fprintf(stderr, "Activator v%s\n", PACKAGE_VERSION);
    fputs("\n", stderr);
    fputs("Usage:\n", stderr);
    fputs("  activator <command> [arguments]\n", stderr);
    fputs("\n", stderr);
    fputs("Commands:\n", stderr);
    [self printUsageCommand:@"listeners" maximumWidth:32 description:@"List available listeners."];
    [self printUsageCommand:@"events" maximumWidth:32 description:@"List available events."];
    [self printUsageCommand:@"modes" maximumWidth:32 description:@"List available event modes."];
    [self printUsageCommand:@"current-mode" maximumWidth:32 description:@"Print the active event mode."];
    [self printUsageCommand:@"current-app" maximumWidth:32 description:@"Print the active application identifier."];
    [self printUsageCommand:@"get <key>" maximumWidth:32 description:@"Print a compatibility preference value."];
    [self printUsageCommand:@"set <key> <value>" maximumWidth:32 description:@"Set a compatibility preference value."];
    [self printUsageCommand:@"activate <event> [<listener>]" maximumWidth:32 description:@"Send an activation event."];
    [self printUsageCommand:@"send <listener>" maximumWidth:32 description:@"Send the default event to a listener."];
    [self printUsageCommand:@"deactivate <event>" maximumWidth:32 description:@"Send a deactivation event."];
#if DEBUG
    fputs("\n", stderr);
    [self printDebugUsageCommands];
#endif
}

#if DEBUG
- (void)printDebugUsage {
    fputs("Usage:\n", stderr);
    fputs("  activator debug <command> [arguments]\n", stderr);
    fputs("\n", stderr);
    [self printDebugUsageCommands];
}

- (void)printDebugUsageCommands {
    fputs("DEBUG only commands:\n", stderr);
    [self printUsageCommand:@"debug assignments list"
               maximumWidth:70
                description:@"List assignments as mode, event, listener TSV."];
    [self printUsageCommand:@"debug assignments get <event> <mode>"
               maximumWidth:70
                description:@"Print matching assignments."];
    [self printUsageCommand:@"debug assignments set <event> <mode> <listener> [...]"
               maximumWidth:70
                description:@"Replace matching assignments."];
    [self printUsageCommand:@"debug assignments add <event> <mode> <listener>"
               maximumWidth:70
                description:@"Add one listener assignment."];
    [self printUsageCommand:@"debug assignments remove <event> <mode> <listener>"
               maximumWidth:70
                description:@"Remove one listener assignment."];
    [self printUsageCommand:@"debug assignments clear <event> <mode>"
               maximumWidth:70
                description:@"Clear matching assignments."];
    [self printUsageCommand:@"debug assignments reset"
               maximumWidth:70
                description:@"Clear current-profile assignments."];
    [self printUsageCommand:@"debug stats [summary]"
               maximumWidth:70
                description:@"Print runtime and assignment statistics."];
    [self printUsageCommand:@"debug stats <events|listeners|abort-events|abort-listeners>"
               maximumWidth:70
                description:@"List non-zero dispatch counters."];
    [self printUsageCommand:@"debug stats <event|listener|abort-event|abort-listener> <name>"
               maximumWidth:70
                description:@"Print one dispatch counter."];
    [self printUsageCommand:@"debug stats reset" maximumWidth:70 description:@"Reset dispatch and abort counters."];
    fputs("  <mode> accepts a mode name, current, or all.\n", stderr);
}
#endif

- (void)printUsageCommand:(NSString *)command
             maximumWidth:(NSUInteger)maximumWidth
              description:(NSString *)description {
    fprintf(stderr, "  %-*s %s\n", (int)maximumWidth, [command UTF8String], [description UTF8String]);
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
