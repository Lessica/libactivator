#import <Activator/Activator.h>

@interface LAEvent () {
    NSString *_name;
    NSString *_mode;
}
@end

@implementation LAEvent

@synthesize name = _name;
@synthesize mode = _mode;

+ (id)eventWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

+ (id)eventWithName:(NSString *)name mode:(NSString *)mode
{
    return [[self alloc] initWithName:name mode:mode];
}

- (id)initWithName:(NSString *)name
{
    return [self initWithName:name mode:nil];
}

- (id)initWithName:(NSString *)name mode:(NSString *)mode
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _mode = [mode copy];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [[coder decodeObjectForKey:@"name"] copy];
        _mode = [[coder decodeObjectForKey:@"mode"] copy];
        _handled = [coder decodeBoolForKey:@"handled"];
        _userInfo = [[coder decodeObjectForKey:@"userInfo"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.mode forKey:@"mode"];
    [coder encodeBool:self.handled forKey:@"handled"];
    [coder encodeObject:self.userInfo forKey:@"userInfo"];
}

- (id)copyWithZone:(NSZone *)zone
{
    LAEvent *event = [[[self class] allocWithZone:zone] initWithName:self.name mode:self.mode];
    event.handled = self.handled;
    event.userInfo = self.userInfo;
    return event;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; name = %@; mode = %@; handled = %@>",
            NSStringFromClass([self class]), self, self.name, self.mode, self.handled ? @"YES" : @"NO"];
}

@end
