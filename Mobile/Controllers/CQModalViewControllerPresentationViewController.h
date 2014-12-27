@interface CQModalViewControllerPresentationViewController : UIViewController
+ (instancetype) viewControllerPresentationViewControllerForViewController:(UIViewController *) viewController;

@property (atomic, strong, readonly) UIViewController *viewControllerToPresent;

- (void) showAboveViewController:(UIViewController *) viewController;
- (void) hide;
@end
