//
//  LAPersistence.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "LAPersistence.h"

#import <HBLog.h>
#import <roothide.h>
#import <sys/stat.h>

@implementation LAPersistence

+ (instancetype)defaultPersistence {
    return [[self alloc] initWithFilePath:jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")];
}

#if DEBUG
+ (instancetype)testingPersistence {
    return [[self alloc] initWithFilePath:jbroot(@"/var/mobile/Library/Preferences/libactivator-tests.plist")];
}
#endif

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        _filePath = [filePath copy];
    }
    return self;
}

- (NSDictionary *)loadDictionary {
    if (self.filePath.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:self.filePath]) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    if (data.length == 0) {
        return nil;
    }

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:nil
                                                           error:&error];
    if (![plist isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    return plist;
}

- (BOOL)saveDictionary:(NSDictionary *)dictionary {
    if (self.filePath.length == 0 || !dictionary) {
        return NO;
    }

    NSString *directory = [self.filePath stringByDeletingLastPathComponent];
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&directoryError]) {
        return NO;
    }

    NSError *serializationError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&serializationError];
    if (!data) {
        return NO;
    }

    NSError *writeError = nil;
    if (![data writeToFile:self.filePath options:NSDataWritingAtomic error:&writeError]) {
        return NO;
    }

    NSDictionary *attributes = @{
        NSFilePosixPermissions : @(S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH),
        NSFileProtectionKey : NSFileProtectionNone,
    };
    NSError *attributesError = nil;
    if (![NSFileManager.defaultManager setAttributes:attributes ofItemAtPath:self.filePath error:&attributesError]) {
        HBLogWarn(@"Failed to update persistence file attributes: %@", attributesError);
    }
    return YES;
}

@end
