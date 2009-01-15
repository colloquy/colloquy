@class CQConnectionEditViewController;

@interface CQConnectionCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQConnectionEditViewController *_editViewController;
	NSURL *_url;
}
@property (nonatomic, retain) NSURL *url;
@end
