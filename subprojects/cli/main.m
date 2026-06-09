//
//  main.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Activator/Activator.h>

@interface LAActivator (LALegacyPreferenceCompatibility)
- (nullable id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(nullable id)value forPreference:(NSString *)preference;
@end

@interface LACommandLineTool : NSObject
- (instancetype)initWithArgc:(int)argc argv:(char *[])argv;
- (int)run;
@end

@implementation LACommandLineTool {
    NSArray<NSString *> *_arguments;
    LAActivator *_activator;
}

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
    if (_arguments.count <= 1) {
        [self printUsage];
        return 0;
    }

    NSString *command = [self argumentAtIndex:1];
    if (_arguments.count == 2) {
        return [self runCommandWithoutArguments:command];
    }
    if (_arguments.count == 3) {
        return [self runCommand:command argument:[self argumentAtIndex:2]];
    }
    if (_arguments.count == 4) {
        return [self runCommand:command firstArgument:[self argumentAtIndex:2] secondArgument:[self argumentAtIndex:3]];
    }

    [self printUsage];
    return 0;
}

- (int)runCommandWithoutArguments:(NSString *)command {
    if ([command isEqualToString:@"listeners"]) {
        [self printObjects:_activator.availableListenerNames];
        return 0;
    }
    if ([command isEqualToString:@"events"]) {
        [self printObjects:_activator.availableEventNames];
        return 0;
    }
    if ([command isEqualToString:@"modes"]) {
        [self printObjects:_activator.availableEventModes];
        return 0;
    }
    if ([command isEqualToString:@"current-mode"]) {
        [self printObject:_activator.currentEventMode];
        return 0;
    }
    if ([command isEqualToString:@"current-app"]) {
        NSString *displayIdentifier = _activator.displayIdentifierForCurrentApplication;
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
        return [self exitStatusForEvent:event];
    }
    if ([command isEqualToString:@"send"]) {
        LAEvent *event = [self eventWithCurrentModeNamed:@"libactivator"];
        [_activator sendEvent:event toListenerWithName:argument];
        return [self exitStatusForEvent:event];
    }
    if ([command isEqualToString:@"deactivate"]) {
        LAEvent *event = [self eventWithCurrentModeNamed:argument];
        [_activator sendDeactivateEventToListeners:event];
        return [self exitStatusForEvent:event];
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
        LAEvent *event = [self eventWithCurrentModeNamed:firstArgument];
        [_activator sendEvent:event toListenerWithName:secondArgument];
        return [self exitStatusForEvent:event];
    }

    [self printUsage];
    return 0;
}

- (int)runGetCommandWithKey:(NSString *)key {
    id value = [_activator _getObjectForPreference:key];
    if (value) {
        [self printObject:value];
    }
    return 0;
}

- (int)runSetCommandWithKey:(NSString *)key value:(NSString *)value {
    [_activator _setObject:value forPreference:key];
    return 0;
}

- (int)runPostInstallCommand {
    return 0;
}

- (LAEvent *)eventWithCurrentModeNamed:(NSString *)eventName {
    return [LAEvent eventWithName:eventName mode:_activator.currentEventMode];
}

- (int)exitStatusForEvent:(LAEvent *)event {
    return event.handled ? 0 : 1;
}

- (NSString *)argumentAtIndex:(NSUInteger)index {
    return index < _arguments.count ? _arguments[index] : @"";
}

- (void)printUsage {
    fprintf(stderr, "Activator version: %ld\n", (long)_activator.version);
    fputs("Usage:\n", stderr);
    fputs("\tactivator listeners\n", stderr);
    fputs("\tactivator events\n", stderr);
    fputs("\tactivator modes\n", stderr);
    fputs("\tactivator current-mode\n", stderr);
    fputs("\tactivator current-app\n", stderr);
    fputs("\tactivator get <key>\n", stderr);
    fputs("\tactivator set <key> <value>\n", stderr);
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
