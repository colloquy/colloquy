@interface CQWelcomeController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	UIViewController *_rootViewController;
	UIStatusBarStyle _previousStatusBarStyle;
	BOOL _shouldShowOnlyHelpTopics;
	BOOL _shouldShowConnections;
}
@property (nonatomic) BOOL shouldShowOnlyHelpTopics;
@property (nonatomic) BOOL shouldShowConnections;
@end
