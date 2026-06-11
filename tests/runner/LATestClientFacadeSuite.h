//
//  LATestClientFacadeSuite.h
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LATestSpringBoardClient;

@interface LATestClientFacadeSuite : NSObject
- (instancetype)initWithClient:(LATestSpringBoardClient *)client NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (NSDictionary *)run;
@end

NS_ASSUME_NONNULL_END
