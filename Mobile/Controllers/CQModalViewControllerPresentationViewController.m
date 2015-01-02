#import "CQModalViewControllerPresentationViewController.h"

@interface CQModalViewControllerPresentationViewController ()
@property (atomic, strong) UIWindow *presentingWindow;
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

- (void) viewDidLoad {
	[super viewDidLoad];

	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognizerTapped:)];
	[self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void) showAboveViewController:(UIViewController *) viewController {
	if (self.presentingWindow) // if we're already showing, don't re-show
		return;

	self.presentingWindow = [[UIWindow alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.frame];
	self.presentingWindow.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin);
	self.presentingWindow.hidden = NO;
	self.presentingWindow.windowLevel = UIWindowLevelAlert + 10;
	self.presentingWindow.transform = [UIApplication sharedApplication].keyWindow.transform;

	UIView *view = [[UIView alloc] initWithFrame:viewController.view.frame];
	view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin);
	view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.3];

	[self.view addSubview:view];

	self.view.alpha = 0.;
	[self.presentingWindow addSubview:self.view];

	[UIView animateWithDuration:.1 animations:^{
		self.view.alpha = 1.0;
	} completion:^(BOOL finished) {
		[self addChildViewController:self.viewControllerToPresent]; {
			[self updateFrameForEdgeInsets];

			CGRect frame = self.viewControllerToPresent.view.frame;
			frame.origin.y -= frame.size.height;
			self.viewControllerToPresent.view.frame = frame;

			[self.view addSubview:self.viewControllerToPresent.view];

			[UIView animateWithDuration:.2 animations:^{
				CGRect frame = self.viewControllerToPresent.view.frame;
				frame.origin.y += frame.size.height;
				self.viewControllerToPresent.view.frame = frame;
			}];
		} [self.viewControllerToPresent didMoveToParentViewController:self];
	}];
}

- (void) hide {
	__weak __typeof__((self)) weakSelf = self;

	[UIView animateWithDuration:.2 animations:^{
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		[strongSelf.viewControllerToPresent willMoveToParentViewController:nil]; {
			CGRect frame = strongSelf.viewControllerToPresent.view.frame;
			frame.origin.y -= frame.size.height;
			strongSelf.viewControllerToPresent.view.frame = frame;
		} [strongSelf.viewControllerToPresent removeFromParentViewController];
	} completion:^(BOOL finished) {
		[UIView animateWithDuration:.1 animations:^{
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			strongSelf.view.alpha = 0.;
		} completion:^(BOOL finished) {
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			strongSelf.presentingWindow.hidden = YES;
			[strongSelf.presentingWindow removeFromSuperview];
			strongSelf.presentingWindow = nil;

			__strong __typeof__((strongSelf.delegate)) strongDelegate = strongSelf.delegate;
			[strongDelegate modalViewControllerPresentationDidCloseViewController:strongSelf];
		}];
	}];
}

- (void) setEdgeInsets:(UIEdgeInsets) edgeInsets {
	_edgeInsets = edgeInsets;

	if (![self.viewControllerToPresent isViewLoaded] || !self.viewControllerToPresent.view.window)
		return;

	[self updateFrameForEdgeInsets];
}

#pragma mark -

- (void) tapGestureRecognizerTapped:(UITapGestureRecognizer *) tapGestureRecognizer {
	[self hide];
}

- (void) updateFrameForEdgeInsets {
	CGRect frame = self.view.frame;
	frame.origin.x = self.edgeInsets.left;
	frame.size.width = CGRectGetWidth(frame) - (self.edgeInsets.left + self.edgeInsets.right);
	frame.origin.y = self.edgeInsets.top;
	frame.size.height = CGRectGetHeight(frame) - (self.edgeInsets.top + self.edgeInsets.bottom);
	self.viewControllerToPresent.view.frame = frame;
}
@end
