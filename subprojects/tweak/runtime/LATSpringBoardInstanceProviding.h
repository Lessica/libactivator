//
//  LATSpringBoardInstanceProviding.h
//  libactivator
//
//  Created by Lessica on 7/13/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSCoverSheetViewController;
@class SBRingerControl;
@class SBVolumeControl;

NS_ASSUME_NONNULL_BEGIN

@protocol LATSpringBoardInstanceProviding <NSObject>

@property(nonatomic, weak, nullable, readonly) CSCoverSheetViewController *coverSheetViewControllerInstance;
@property(nonatomic, weak, nullable, readonly) SBRingerControl *ringerControlInstance;
@property(nonatomic, weak, nullable, readonly) SBVolumeControl *volumeControlInstance;

@end

NS_ASSUME_NONNULL_END
