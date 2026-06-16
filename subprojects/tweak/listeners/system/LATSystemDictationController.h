//
//  LATSystemDictationController.h
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LATSystemAccessibilityElementController;

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemDictationController : NSObject

- (instancetype)init;
- (instancetype)initWithAccessibilityElementController:
    (LATSystemAccessibilityElementController *)accessibilityElementController NS_DESIGNATED_INITIALIZER;

- (BOOL)startDictationForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
