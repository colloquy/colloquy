@interface CQRootContainerViewController : UIViewController
@property (strong, readonly) UIViewController *rootViewController;

- (void) buildRootViewController;
@end
