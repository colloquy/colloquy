@class MVChatConnection;

@interface CQConnectionBouncerDetailsEditController : UITableViewController <UIActionSheetDelegate> {
	@protected
	MVChatConnection *_connection;
	NSUInteger _bouncerIndex;
	NSMutableDictionary *_settings;
	BOOL _newSettings;
	BOOL _removed;
}
@property (nonatomic, retain) MVChatConnection *connection;
@property (nonatomic, assign) NSUInteger bouncerIndex;
@property (nonatomic, copy) NSDictionary *settings;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@end
