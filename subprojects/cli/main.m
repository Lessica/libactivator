//
//  main.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Activator/Activator.h>

static void LAPrintUsage(void) {
    puts("Usage:");
    puts("  activator listeners");
    puts("  activator events");
    puts("  activator modes");
    puts("  activator current-mode");
    puts("  activator current-app");
    puts("  activator get <key>");
    puts("  activator set <key> <value>");
    puts("  activator activate <event> [<listener>]");
    puts("  activator send <listener>");
    puts("  activator deactivate <event>");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc <= 1 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 ||
            strcmp(argv[1], "-h") == 0) {
            LAPrintUsage();
            return 0;
        }

        if (strcmp(argv[1], "version") == 0 || strcmp(argv[1], "--version") == 0) {
            printf("%ld\n", (long)[LAActivator sharedInstance].version);
            return 0;
        }

        fprintf(stderr, "activator: command is not implemented yet: %s\n", argv[1]);
        return 64;
    }
}
