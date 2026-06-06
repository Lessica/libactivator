#import <Foundation/Foundation.h>

__attribute__((visibility("hidden")))
@interface LAActivatorPersistence : NSObject

@property(nonatomic, copy, readonly) NSString *filePath;

+ (instancetype)defaultPersistence;
- (instancetype)initWithFilePath:(NSString *)filePath;
- (NSDictionary *)loadDictionary;
- (BOOL)saveDictionary:(NSDictionary *)dictionary;
- (void)backupInvalidDictionary;

@end
