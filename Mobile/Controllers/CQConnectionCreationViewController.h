@class CQConnectionEditViewController;
@class MVChatConnection;

@interface CQConnectionCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	MVChatConnection *_connection;
	CQConnectionEditViewController *_editViewController;
}
@property (nonatomic, copy) NSURL *url;
@end
