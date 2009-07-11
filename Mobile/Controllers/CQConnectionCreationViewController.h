@class CQConnectionEditViewController;
@class MVChatConnection;

@interface CQConnectionCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	MVChatConnection *_connection;
	CQConnectionEditViewController *_editViewController;
	UIStatusBarStyle _previousStatusBarStyle;
}
@property (nonatomic, copy) NSURL *url;
@end
