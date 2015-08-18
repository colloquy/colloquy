#import "UINavigationControllerAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  UINavigationController (UINavigationControllerColloquyAdditions)
- (UIViewController *) rootViewController {
	if (self.viewControllers.count)
		return self.viewControllers[0];
	return nil;
}
@end

NS_ASSUME_NONNULL_END
