//
//  LATestCountingPersistence.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestCountingPersistence.h"

@implementation LATestCountingPersistence

- (BOOL)saveDictionary:(NSDictionary *)dictionary {
    self.saveCount += 1;
    self.lastSavedDictionary = dictionary;
    return YES;
}

@end

