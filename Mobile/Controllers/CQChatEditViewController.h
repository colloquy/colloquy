@class MVChatConnection;

@interface CQChatEditViewController : UITableViewController {
	@protected
	BOOL _roomTarget;
	NSMutableArray *_sortedConnections;
	MVChatConnection *_selectedConnection;
	NSString *_name;
	NSString *_password;
}
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@property (nonatomic, readonly) MVChatConnection *selectedConnection;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *password;
@end
