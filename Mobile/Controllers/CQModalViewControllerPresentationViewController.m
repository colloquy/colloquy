#import "CQModalViewControllerPresentationViewController.h"

@interface CQModalViewControllerPresentationViewController ()
@property (atomic, strong, readwrite) UIViewController *viewControllerToPresent;
@end

@implementation CQModalViewControllerPresentationViewController
+ (instancetype) viewControllerPresentationViewControllerForViewController:(UIViewController *) viewController {
	if (!viewController)
		return nil;

	CQModalViewControllerPresentationViewController *viewControllerPresentationViewController = [[CQModalViewControllerPresentationViewController alloc] init];
	viewControllerPresentationViewController.viewControllerToPresent = viewController;

	return viewControllerPresentationViewController;
}

- (void) showAboveViewController:(UIViewController *) viewController {
	UIView *view = [[UIView alloc] initWithFrame:viewController.view.frame];
	view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin);
	view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.3];

	[self.view addSubview:view];

	[self addChildViewController:self.viewControllerToPresent]; {
		[self.view addSubview:self.viewControllerToPresent.view];
	} [self.viewControllerToPresent didMoveToParentViewController:self];

	[viewController.view.window addSubview:self.view];

	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognizerTapped:)];
	[self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void) hide {
	[self.viewControllerToPresent willMoveToParentViewController:nil]; {
		[self.viewControllerToPresent.view removeFromSuperview];
	} [self.viewControllerToPresent removeFromParentViewController];

	[self.view removeFromSuperview];
}

- (void) tapGestureRecognizerTapped:(UITapGestureRecognizer *) tapGestureRecognizer {
	[self hide];
}
@end
