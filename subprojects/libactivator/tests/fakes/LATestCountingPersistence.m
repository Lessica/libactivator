//
//  LATestCountingPersistence.m
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LATestCountingPersistence.h"

@interface LATestCountingPersistence () {
    NSLock *_stateLock;
}
@property(nonatomic, assign) NSUInteger activeSaveCount;
@end

@implementation LATestCountingPersistence

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super initWithFilePath:filePath];
    if (self) {
        _stateLock = [[NSLock alloc] init];
        _stateLock.name = @"libactivator.tests.counting-persistence";
    }
    return self;
}

- (BOOL)saveDictionary:(NSDictionary *)dictionary {
    BOOL failsSave = NO;
    [_stateLock lock];
    self.saveCount += 1;
    self.activeSaveCount += 1;
    self.maximumConcurrentSaveCount = MAX(self.maximumConcurrentSaveCount, self.activeSaveCount);
    failsSave = self.failsSaves;
    [_stateLock unlock];

    if (self.saveStartedSemaphore) {
        dispatch_semaphore_signal(self.saveStartedSemaphore);
    }
    if (self.saveDelay > 0.0) {
        [NSThread sleepForTimeInterval:self.saveDelay];
    }

    [_stateLock lock];
    if (!failsSave) {
        self.lastSavedDictionary = dictionary;
    }
    self.activeSaveCount -= 1;
    [_stateLock unlock];
    return !failsSave;
}

@end
