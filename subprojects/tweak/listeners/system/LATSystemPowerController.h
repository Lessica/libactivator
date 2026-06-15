//
//  LATSystemPowerController.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemPowerController : NSObject
- (BOOL)respringForListenerName:(NSString *)listenerName;
- (BOOL)hardRespringForListenerName:(NSString *)listenerName;
- (BOOL)safeModeForListenerName:(NSString *)listenerName;
- (BOOL)powerDownForListenerName:(NSString *)listenerName;
- (BOOL)rebootForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
