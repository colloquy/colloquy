@interface CQWelcomeNavigationController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	UIViewController *_rootViewController;
	UIStatusBarStyle _previousStatusBarStyle;
	BOOL _shouldShowOnlyHelpTopics;
}
@property (nonatomic) BOOL shouldShowOnlyHelpTopics;
@end
