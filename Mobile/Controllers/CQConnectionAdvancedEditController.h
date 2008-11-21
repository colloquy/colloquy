@class MVChatConnection;

@interface CQConnectionAdvancedEditController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
	IBOutlet UITableView *editTableView;
	UITextField *_currentEditingTextField;
	MVChatConnection *_connection;
	BOOL _newConnection;
}
@property (nonatomic, assign) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end
