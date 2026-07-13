//
//  LATNowPlayingProviding.h
//  libactivator
//
//  Created by Lessica on 7/14/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LATNowPlayingApplicationDisplayIdentifierCompletion)(NSString *_Nullable displayIdentifier);

@protocol LATNowPlayingProviding <NSObject>

- (BOOL)requestNowPlayingApplicationDisplayIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion;
- (BOOL)getKnownNowPlayingApplicationPlaying:(BOOL *)isPlaying;

@end

NS_ASSUME_NONNULL_END
