@class MVChatConnection;

@interface CQConnectionPushEditController : UITableViewController {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
