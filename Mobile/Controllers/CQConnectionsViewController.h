@class MVChatConnection;

@interface CQConnectionsViewController : UITableViewController <UIActionSheetDelegate> {
	@protected
	NSTimer *_connectTimeUpdateTimer;
	BOOL _active;
}
- (void) update;

- (void) connectionAdded:(MVChatConnection *) connection;
- (void) connectionRemovedAtIndexPath:(NSIndexPath *) indexPath;

- (void) updateConnection:(MVChatConnection *) connection;

- (NSIndexPath *) indexPathForConnection:(MVChatConnection *) connection;
- (MVChatConnection *) connectionAtIndexPath:(NSIndexPath *) indexPath;
@end
