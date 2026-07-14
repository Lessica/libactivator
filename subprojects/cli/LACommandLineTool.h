//
//  LACommandLineTool.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LACommandLineTool : NSObject

- (instancetype)initWithArgc:(int)argc argv:(char *_Nonnull const *_Nonnull)argv;
- (int)run;

@end

NS_ASSUME_NONNULL_END
