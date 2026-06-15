//
//  LATComposeActionPresenter.h
//  libactivator
//
//  Created by Lessica on 6/15/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "compose/LATComposeActionCommand.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATComposeActionPresenter : NSObject
- (BOOL)performComposeAction:(LATComposeActionKind)kind listenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
