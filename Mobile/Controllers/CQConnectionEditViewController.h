@class MVChatConnection;

@interface CQConnectionEditViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	IBOutlet UITableView *editTableView;
	MVChatConnection *_connection;
}
@property (nonatomic, assign) MVChatConnection *connection;
@end
