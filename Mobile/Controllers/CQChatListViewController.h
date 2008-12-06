@protocol CQChatViewController;

@interface CQChatListViewController : UITableViewController
- (void) addChatViewController:(id <CQChatViewController>) controller;
- (void) selectChatViewController:(id <CQChatViewController>) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end
