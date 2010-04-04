#import "CQChatController.h"

@class MVChatConnection;
@class CQChatListViewController;

@interface CQChatNavigationController : UINavigationController <UINavigationControllerDelegate> {
	CQChatListViewController *_chatListViewController;
	BOOL _active;
}
- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end
