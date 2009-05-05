@class MVChatConnection;

@interface CQConnectionBouncerEditController : UITableViewController {
	@protected
	MVChatConnection *_connection;
	NSUInteger _lastSelectedBouncerIndex;
	BOOL _bouncerEnabled;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
