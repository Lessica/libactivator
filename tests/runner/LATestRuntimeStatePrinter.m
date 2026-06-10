//
//  LATestRuntimeStatePrinter.m
//  libactivator-tests
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestRuntimeStatePrinter.h"

@implementation LATestRuntimeStatePrinter

- (void)printHeader {
    printf("[runtime] time mode underneath display frontMost screenOn uiLocked lockVisible sbInterface inLockScreen "
           "homeSources springBoardSources lockSources\n");
    fflush(stdout);
}

- (void)printRuntimeState:(NSDictionary *)state {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";

    NSArray *homeSourceValues = [state[@"HomeSources"] isKindOfClass:NSArray.class] ? state[@"HomeSources"] : @[];
    NSArray *springBoardSourceValues = [state[@"SpringBoardInterfaceSources"] isKindOfClass:NSArray.class]
                                           ? state[@"SpringBoardInterfaceSources"]
                                           : @[];
    NSArray *lockSourceValues = [state[@"LockSources"] isKindOfClass:NSArray.class] ? state[@"LockSources"] : @[];
    NSString *homeSources = [homeSourceValues componentsJoinedByString:@","];
    NSString *springBoardSources = [springBoardSourceValues componentsJoinedByString:@","];
    NSString *lockSources = [lockSourceValues componentsJoinedByString:@","];
    NSString *mode = [state[@"Mode"] isKindOfClass:NSString.class] ? state[@"Mode"] : @"";
    NSString *underneathMode = [state[@"UnderneathMode"] isKindOfClass:NSString.class] ? state[@"UnderneathMode"] : @"";
    NSString *displayIdentifier =
        [state[@"DisplayIdentifier"] isKindOfClass:NSString.class] ? state[@"DisplayIdentifier"] : @"";
    NSString *frontMost = [state[@"FrontMost"] isKindOfClass:NSString.class] ? state[@"FrontMost"] : @"";

    printf("[runtime] %s mode=%s underneath=%s display=%s frontMost=%s screenOn=%s uiLocked=%s lockVisible=%s "
           "sbInterface=%s inLockScreen=%s home=%s springBoard=%s lock=%s\n",
           [[formatter stringFromDate:NSDate.date] UTF8String], [mode UTF8String], [underneathMode UTF8String],
           [displayIdentifier UTF8String], [frontMost UTF8String], [state[@"ScreenOn"] boolValue] ? "YES" : "NO",
           [state[@"UILocked"] boolValue] ? "YES" : "NO", [state[@"LockScreenVisible"] boolValue] ? "YES" : "NO",
           [state[@"SpringBoardInterfaceVisible"] boolValue] ? "YES" : "NO",
           [state[@"InLockScreen"] boolValue] ? "YES" : "NO", [homeSources UTF8String], [springBoardSources UTF8String],
           [lockSources UTF8String]);
    fflush(stdout);
}

@end
