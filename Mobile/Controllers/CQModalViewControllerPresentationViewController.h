@interface CQModalViewControllerPresentationViewController : UIViewController
+ (instancetype) viewControllerPresentationViewControllerForViewController:(UIViewController *) viewController;

@property (atomic, strong, readonly) UIViewController *viewControllerToPresent;
@property (nonatomic, assign) UIEdgeInsets edgeInsets;

- (void) showAboveViewController:(UIViewController *) viewController;
- (void) hide;
@end
