@class MVChatConnection;

@interface CQConnectionEditViewController : UITableViewController <UIActionSheetDelegate> {
	@protected
	MVChatConnection *_connection;
	NSArray *_servers;
	BOOL _newConnection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end
