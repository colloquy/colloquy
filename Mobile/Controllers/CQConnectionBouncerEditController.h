@class MVChatConnection;

@interface CQConnectionBouncerEditController : UITableViewController {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, assign) MVChatConnection *connection;
@end
