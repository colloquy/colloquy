@class MVChatConnection;

@interface CQConnectionsViewController : UITableViewController <UIActionSheetDelegate> {
	@protected
	NSTimer *_connectTimeUpdateTimer;
	BOOL _active;
}
- (void) addConnection:(MVChatConnection *) connection;
- (void) removeConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection forBouncerIdentifier:(NSString *) identifier;
- (void) removeConnection:(MVChatConnection *) connection forBouncerIdentifier:(NSString *) identifier;

- (void) updateConnection:(MVChatConnection *) connection;

- (NSIndexPath *) indexPathForConnection:(MVChatConnection *) connection;
- (MVChatConnection *) connectionAtIndexPath:(NSIndexPath *) indexPath;
@end
