//
//  LATMediaEventSource.h
//  libactivator
//
//  Created by Lessica on 6/11/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LATNowPlayingApplicationDisplayIdentifierCompletion)(NSString *_Nullable displayIdentifier);

@interface LATMediaEventSource : NSObject

// Main-queue confined. This source owns media-related event acquisition and submits events to the
// SpringBoard dispatch engine, so callers must start it from the SpringBoard main queue.
- (void)start;

// Main-queue entry point. MediaRemote answers on an internal queue and this source returns the completion
// on the main queue so listener code can stay independent from MediaRemote threading details.
- (BOOL)requestNowPlayingApplicationDisplayIdentifierWithCompletion:
    (LATNowPlayingApplicationDisplayIdentifierCompletion)completion;

@end

NS_ASSUME_NONNULL_END
