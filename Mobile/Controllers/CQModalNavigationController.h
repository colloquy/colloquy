@interface CQModalNavigationController : UINavigationController <UINavigationControllerDelegate> {
@protected
	UIViewController *_rootViewController;
}
- (void) close:(id) sender;
@end
