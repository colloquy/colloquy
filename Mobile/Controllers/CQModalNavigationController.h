@interface CQModalNavigationController : UINavigationController <UINavigationControllerDelegate> {
@protected
	UIViewController *_rootViewController;
	UIStatusBarStyle _previousStatusBarStyle;

	id _userInfo;
}
@property (nonatomic, retain) id userInfo;

- (void) close:(id) sender;
@end
