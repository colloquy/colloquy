#import "CQChatTableCell.h"

@protocol CQChatViewController;

@interface CQChatListViewController : UITableViewController <UIActionSheetDelegate> {
	@protected
	BOOL _active;
	BOOL _needsUpdate;
}
- (void) addChatViewController:(id) controller;
- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end
