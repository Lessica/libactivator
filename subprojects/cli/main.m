//
//  main.m
//  libactivator
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LACommandLineTool.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        LACommandLineTool *tool = [[LACommandLineTool alloc] initWithArgc:argc argv:argv];
        return [tool run];
    }
}
