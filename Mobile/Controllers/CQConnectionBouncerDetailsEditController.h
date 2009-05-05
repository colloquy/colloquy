@class MVChatConnection;
@class CQBouncerSettings;

@interface CQConnectionBouncerDetailsEditController : UITableViewController <UIActionSheetDelegate> {
	@protected
	MVChatConnection *_connection;
	CQBouncerSettings *_settings;
	BOOL _newSettings;
}
@property (nonatomic, retain) MVChatConnection *connection;
@property (nonatomic, copy) CQBouncerSettings *settings;
@end
