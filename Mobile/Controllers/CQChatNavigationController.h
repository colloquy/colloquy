@class MVChatConnection;
@class CQChatListViewController;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatNavigationController : UINavigationController <UINavigationControllerDelegate> {
	CQChatListViewController *_chatListViewController;
	BOOL _active;
}
- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end

NS_ASSUME_NONNULL_END
