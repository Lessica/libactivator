//
//  LATestRunner.h
//  libactivator-tests
//
//  Created by Lessica on 6/8/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestRunner : NSObject

#pragma mark - Commands

- (int)runStableTests;
- (int)runRuntimeInputTests;
- (int)runDeviceRuntimeTests;
- (int)watchRuntimeState;

@end

NS_ASSUME_NONNULL_END
