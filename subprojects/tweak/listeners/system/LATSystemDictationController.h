//
//  LATSystemDictationController.h
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LATSystemAccessibilityElementController;

@interface LATSystemDictationController : NSObject

- (instancetype)initWithAccessibilityElementController:(LATSystemAccessibilityElementController *)accessibilityElementController
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (BOOL)startDictationForListenerName:(NSString *)listenerName;

@end

NS_ASSUME_NONNULL_END
