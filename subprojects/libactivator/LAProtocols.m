#import <Activator/Activator.h>

#import <objc/runtime.h>

__attribute__((used))
static void LAActivatorReferencePublicProtocols(void)
{
    (void)@protocol(LAListener);
    (void)@protocol(LAEventDataSource);
}
