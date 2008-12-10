@class CQConnectionEditViewController;

@interface CQConnectionCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	CQConnectionEditViewController *_editViewController;
	NSURL *_url;
}
@property (nonatomic, retain) NSURL *url;
@end
