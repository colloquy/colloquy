@interface CQModalNavigationController : UINavigationController <UINavigationControllerDelegate> {
@protected
	UIViewController *_rootViewController;
	UIBarButtonSystemItem _closeButtonItem;
}
- (void) close:(id) sender;

@property (nonatomic) UIBarButtonSystemItem closeButtonItem;
@end
