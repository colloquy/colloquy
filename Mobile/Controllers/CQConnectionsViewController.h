@class CQConnectionCreationViewController;

@interface CQConnectionsViewController : UITableViewController <UIActionSheetDelegate> {
	CQConnectionCreationViewController *_connectionCreationViewController;
	NSTimer *_connectTimeUpdateTimer;
}
- (void) addConnection:(MVChatConnection *) connection;
- (void) removeConnection:(MVChatConnection *) connection;
@end
