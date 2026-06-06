#import "LAActivatorPrivate.h"

__attribute__((constructor))
static void LATweakInitialize(void)
{
    [[LAActivator sharedInstance] startIPCServerIfNeeded];
}
