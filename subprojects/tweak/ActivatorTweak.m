//
//  ActivatorTweak.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAActivatorPrivate.h"

__attribute__((constructor)) static void LATweakInitialize(void) {
    [[LAActivator sharedInstance] startIPCServerIfNeeded];
}
