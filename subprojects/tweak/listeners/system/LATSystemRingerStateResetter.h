//
//  LATSystemRingerStateResetter.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATSystemRingerStateResetter : NSObject
- (BOOL)resetRingerStateForListenerName:(NSString *)listenerName;
@end

NS_ASSUME_NONNULL_END
