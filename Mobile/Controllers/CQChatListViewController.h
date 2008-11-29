@protocol CQChatViewController;

@interface CQChatListViewController : UITableViewController
- (void) addChatViewController:(id <CQChatViewController>) controller;
@end
