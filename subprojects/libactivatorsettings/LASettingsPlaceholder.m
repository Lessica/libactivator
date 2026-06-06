#import <UIKit/UIKit.h>

#import "LAPath.h"

UIViewController *LASCreateSettingsRootViewController(void)
{
    (void)LAJailbreakRootPath(@"/Library/Frameworks");
    return [[UIViewController alloc] init];
}
