@class CQModalViewControllerPresentationViewController;
@protocol CQModalViewControllerPresentationViewControllerDelegate <NSObject>
@required
- (void) modalViewControllerPresentationDidCloseViewController:(CQModalViewControllerPresentationViewController *) modalViewControllerPresentationViewController;
@end

@interface CQModalViewControllerPresentationViewController : UIViewController
+ (instancetype) viewControllerPresentationViewControllerForViewController:(UIViewController *) viewController;

@property (atomic, weak) id <CQModalViewControllerPresentationViewControllerDelegate> delegate;
@property (atomic, strong, readonly) UIViewController *viewControllerToPresent;
@property (nonatomic, assign) UIEdgeInsets edgeInsets;

- (void) showAboveViewController:(UIViewController *) viewController;
- (void) hide;
@end
