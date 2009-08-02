#import "CQChatTableCell.h"

@protocol CQChatViewController;

@interface CQChatListViewController : UITableViewController {
	@protected
	BOOL _active;
	BOOL _needsUpdate;
}
- (void) addChatViewController:(id) controller;
- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
- (void) updateAccessibilityLabelForChatCell:(CQChatTableCell *) cell;
@end
