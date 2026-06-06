//
//  LAProtocols.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

#import <objc/runtime.h>

__attribute__((used)) static void LAActivatorReferencePublicProtocols(void) {
    (void)@protocol(LAListener);
    (void)@protocol(LAEventDataSource);
}
