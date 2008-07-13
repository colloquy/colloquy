@class CQConnectionCreationViewController;

@interface CQConnectionsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate> {
	IBOutlet UITableView *connectionsTableView;
	IBOutlet CQConnectionCreationViewController *connectionCreationViewController;
	NSTimer *_connectTimeUpdateTimer;
}
- (void) addConnection:(MVChatConnection *) connection;
- (void) removeConnection:(MVChatConnection *) connection;
@end
