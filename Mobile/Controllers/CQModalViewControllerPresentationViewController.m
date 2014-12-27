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
	if (self.viewControllerToPresent.view.window)
		return;

	CGRect frame = viewController.view.frame;
	UIView *view = [[UIView alloc] initWithFrame:frame];
	view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin);
	view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.3];

	[self.view addSubview:view];

	[self addChildViewController:self.viewControllerToPresent]; {
		frame.origin.x = self.edgeInsets.left;
		frame.size.width = CGRectGetWidth(frame) - (self.edgeInsets.left + self.edgeInsets.right);
		frame.origin.y = self.edgeInsets.top;
		frame.size.height = CGRectGetHeight(frame) - (self.edgeInsets.top + self.edgeInsets.bottom);
		self.viewControllerToPresent.view.frame = frame;

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

- (void) setEdgeInsets:(UIEdgeInsets) edgeInsets {
	_edgeInsets = edgeInsets;

	if (![self.viewControllerToPresent isViewLoaded] || !self.viewControllerToPresent.view.window)
		return;

	// adjust view since we're presented
}

#pragma mark -

- (void) tapGestureRecognizerTapped:(UITapGestureRecognizer *) tapGestureRecognizer {
	[self hide];
}
@end
