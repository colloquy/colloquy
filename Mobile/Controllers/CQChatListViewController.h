@protocol CQChatViewController;

@interface CQChatListViewController : UITableViewController {
	BOOL _active;
	BOOL _needsUpdate;
}
- (void) addChatViewController:(id <CQChatViewController>) controller;
- (void) selectChatViewController:(id <CQChatViewController>) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;

- (void) addMessagePreview:(NSDictionary *) info forChatController:(id <CQChatViewController>)controller;
@end
