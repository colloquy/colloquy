#import "UINavigationControllerAdditions.h"

@implementation UINavigationController (UINavigationControllerColloquyAdditions)
- (UIViewController *) rootViewController {
	return [self.viewControllers objectAtIndex:0];
}
@end
