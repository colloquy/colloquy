@class CQChatEditViewController;
@class MVChatConnection;

@interface CQChatCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQChatEditViewController *_editViewController;
	BOOL _roomTarget;
	MVChatConnection *_selectedConnection;
	NSString *_name;
	NSString *_password;
	UIStatusBarStyle _previousStatusBarStyle;
	BOOL _showListOnLoad;
	NSString *_searchString;
}
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@property (nonatomic, retain) MVChatConnection *selectedConnection;

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString;
@end
