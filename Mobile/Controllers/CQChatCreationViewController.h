@class CQChatEditViewController;

@interface CQChatCreationViewController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQChatEditViewController *_editViewController;
	BOOL _roomTarget;
	UIStatusBarStyle _previousStatusBarStyle;
}
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@end
