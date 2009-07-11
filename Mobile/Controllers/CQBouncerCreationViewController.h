@class CQBouncerEditViewController;
@class CQBouncerSettings;

@interface CQBouncerCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQBouncerSettings *_settings;
	CQBouncerEditViewController *_editViewController;
	UIStatusBarStyle _previousStatusBarStyle;
}
@end
