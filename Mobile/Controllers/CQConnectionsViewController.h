@class MVChatConnection;

@interface CQConnectionsViewController : UITableViewController <UIActionSheetDelegate> {
	NSTimer *_connectTimeUpdateTimer;
}
- (void) addConnection:(MVChatConnection *) connection;
- (void) removeConnection:(MVChatConnection *) connection;
@end
