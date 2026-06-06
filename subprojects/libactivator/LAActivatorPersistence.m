#import "LAActivatorPersistence.h"

#import <roothide.h>
#import <unistd.h>

@implementation LAActivatorPersistence

+ (instancetype)defaultPersistence {
    return [[self alloc] initWithFilePath:jbroot(@"/var/mobile/Library/Preferences/libactivator.plist")];
}

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
        [self backupInvalidDictionary];
        return nil;
    }

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:nil
                                                           error:&error];
    if (![plist isKindOfClass:NSDictionary.class]) {
        [self backupInvalidDictionary];
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
    return [data writeToFile:self.filePath options:NSDataWritingAtomic error:&writeError];
}

- (void)backupInvalidDictionary {
    if (self.filePath.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:self.filePath]) {
        return;
    }

    NSString *backupPath = [self.filePath stringByAppendingFormat:@".invalid-%lld-%d",
                                                      (long long)[NSDate.date timeIntervalSince1970], getpid()];
    [NSFileManager.defaultManager moveItemAtPath:self.filePath toPath:backupPath error:nil];
}

@end
