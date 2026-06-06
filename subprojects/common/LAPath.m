#import "LAPath.h"

#import <roothide.h>

NSString *LAJailbreakRootPath(NSString *path)
{
    return jbroot(path);
}

NSString *LARootFileSystemPath(NSString *path)
{
    return rootfs(path);
}
