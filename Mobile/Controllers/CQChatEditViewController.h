@interface CQChatEditViewController : UITableViewController {
	BOOL _roomTarget;
	NSUInteger _selectedConnectionIndex;
	NSString *_name;
	NSString *_password;
}
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@property (nonatomic, readonly) NSUInteger selectedConnectionIndex;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *password;
@end
