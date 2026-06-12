//
//  LATSystemActionCommand.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LATSystemActionKind) {
    LATSystemActionKindVolumeHUD,
    LATSystemActionKindNowPlayingApplication,
    LATSystemActionKindRingerReset,
    LATSystemActionKindRingerMute,
    LATSystemActionKindRingerUnmute,
    LATSystemActionKindRingerToggle,
    LATSystemActionKindFirstSpringBoardPage,
};

@interface LATSystemActionCommand : NSObject

@property(nonatomic, copy, readonly) NSString *listenerName;
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, assign, readonly) LATSystemActionKind kind;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithListenerName:(NSString *)listenerName
                        selectorName:(NSString *)selectorName
                                kind:(LATSystemActionKind)kind NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
