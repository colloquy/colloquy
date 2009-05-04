@class MVChatConnection;

@interface CQConnectionBouncerEditController : UITableViewController {
	@protected
	MVChatConnection *_connection;
	NSUInteger _lastSelectedBouncerIndex;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
