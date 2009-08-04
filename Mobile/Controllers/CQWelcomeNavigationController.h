@class CQWelcomeViewController;

@interface CQWelcomeNavigationController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQWelcomeViewController *_welcomeViewController;
	UIStatusBarStyle _previousStatusBarStyle;
}

@end
