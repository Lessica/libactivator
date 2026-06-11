//
//  LATestBuiltInTelephonyActionsSuite.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <Foundation/Foundation.h>

@class LATestRecorder;

@interface LATestBuiltInTelephonyActionsSuite : NSObject
+ (void)runWithRecorder:(LATestRecorder *)recorder activator:(LAActivator *)activator;
@end
