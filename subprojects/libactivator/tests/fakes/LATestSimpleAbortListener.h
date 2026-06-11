//
//  LATestSimpleAbortListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestSimpleAbortListener : NSObject <LAListener>
@property(nonatomic, assign) NSInteger abortCount;
@end

NS_ASSUME_NONNULL_END
