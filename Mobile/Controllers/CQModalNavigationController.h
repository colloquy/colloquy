@interface CQModalNavigationController : UINavigationController <UINavigationControllerDelegate> {
@protected
	UIViewController *_rootViewController;
	UIStatusBarStyle _previousStatusBarStyle;
}
- (void) close:(id) sender;
@end
