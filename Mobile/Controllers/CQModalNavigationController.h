NS_ASSUME_NONNULL_BEGIN

@interface CQModalNavigationController : UINavigationController <UINavigationControllerDelegate> {
@protected
	UIViewController *_rootViewController;
	UIBarButtonSystemItem _closeButtonItem;
}
- (void) close:(__nullable id) sender;

@property (nonatomic) UIBarButtonSystemItem closeButtonItem;
@end

NS_ASSUME_NONNULL_END
