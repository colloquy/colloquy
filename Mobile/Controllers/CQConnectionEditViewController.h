@class MVChatConnection;
@class CQConnectionAdvancedEditController;

@interface CQConnectionEditViewController : UITableViewController <UIActionSheetDelegate> {
	CQConnectionAdvancedEditController *_advancedEditViewController;
	MVChatConnection *_connection;
	BOOL _newConnection;
}
@property (nonatomic, assign) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end
