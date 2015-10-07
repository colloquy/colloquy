#import "CQTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQChatListViewController : CQTableViewController
@property (nonatomic) BOOL active;

- (void) chatViewControllerAdded:(id) controller;

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end

NS_ASSUME_NONNULL_END
