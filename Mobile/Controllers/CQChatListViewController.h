NS_ASSUME_NONNULL_BEGIN

@interface CQChatListViewController : UITableViewController
@property (nonatomic) BOOL active;

- (void) chatViewControllerAdded:(id) controller;

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end

NS_ASSUME_NONNULL_END
