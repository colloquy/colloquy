#import "UINavigationControllerAdditions.h"

@implementation UINavigationController (UINavigationControllerColloquyAdditions)
- (UIViewController *) rootViewController {
	if (self.viewControllers.count)
		return [self.viewControllers objectAtIndex:0];
	return nil;
}
@end
