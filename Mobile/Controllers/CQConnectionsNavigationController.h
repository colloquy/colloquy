@class CQConnectionsViewController;
@class MVChatConnection;
@class CQBouncerSettings;

@interface CQConnectionsNavigationController : UINavigationController <UINavigationControllerDelegate> {
	CQConnectionsViewController *_connectionsViewController;
	BOOL _wasEditing;
}
- (void) editConnection:(MVChatConnection *) connection;
- (void) editBouncer:(CQBouncerSettings *) settings;
@end
