//
//  LATestRuntimeStatePrinter.h
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestRuntimeStatePrinter : NSObject
- (void)printHeader;
- (void)printRuntimeState:(NSDictionary *)state;
@end

NS_ASSUME_NONNULL_END
