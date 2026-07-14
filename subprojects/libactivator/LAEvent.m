//
//  LAEvent.m
//  libactivator
//
//  Created by Lessica on 6/6/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

@implementation LAEvent

+ (instancetype)eventWithName:(NSString *)name {
    return [[self alloc] initWithName:name];
}

+ (instancetype)eventWithName:(NSString *)name mode:(NSString *)mode {
    return [[self alloc] initWithName:name mode:mode];
}

- (instancetype)initWithName:(NSString *)name {
    return [self initWithName:name mode:nil];
}

- (instancetype)initWithName:(NSString *)name mode:(NSString *)mode {
    self = [super init];
    if (self) {
        _name = [name copy];
        _mode = [mode copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        id name = [coder decodeObjectForKey:@"name"];
        id mode = [coder decodeObjectForKey:@"mode"];
        id userInfo = [coder decodeObjectForKey:@"userInfo"];
        _name = [name isKindOfClass:NSString.class] ? [name copy] : @"";
        _mode = [mode isKindOfClass:NSString.class] ? [mode copy] : nil;
        _handled = [coder decodeBoolForKey:@"handled"];
        _userInfo = [userInfo isKindOfClass:NSDictionary.class] ? [userInfo copy] : nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.mode forKey:@"mode"];
    [coder encodeBool:self.handled forKey:@"handled"];
    [coder encodeObject:self.userInfo forKey:@"userInfo"];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    LAEvent *event = [[[self class] allocWithZone:zone] initWithName:self.name mode:self.mode];
    event.handled = self.handled;
    event.userInfo = self.userInfo;
    return event;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; name = %@; mode = %@; handled = %@>", NSStringFromClass([self class]),
                                      self, self.name, self.mode, self.handled ? @"YES" : @"NO"];
}

@end
