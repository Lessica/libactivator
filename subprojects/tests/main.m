//
//  main.m
//  libactivator-tests
//
//  Created by Lessica on 6/7/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LATestRunner.h"

int main(int argc, char **argv) {
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);
    @autoreleasepool {
        LATestRunner *runner = [[LATestRunner alloc] init];
        if (argc > 1 && strcmp(argv[1], "watch-runtime") == 0) {
            return [runner watchRuntimeState];
        }
        if (argc <= 1 || strcmp(argv[1], "run") == 0) {
            return [runner runStableTests];
        }
        if (strcmp(argv[1], "run-runtime-input") == 0) {
            return [runner runRuntimeInputTests];
        }
        if (strcmp(argv[1], "run-device-runtime") == 0) {
            return [runner runDeviceRuntimeTests];
        }
        fprintf(stderr, "Usage: %s [run|run-runtime-input|run-device-runtime|watch-runtime]\n", argv[0]);
        return 64;
    }
}
