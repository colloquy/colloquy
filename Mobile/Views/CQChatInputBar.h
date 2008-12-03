@protocol CQChatInputBarDelegate;

@interface CQChatInputBar : UIView <UITextFieldDelegate> {
	UITextField *_inputField;
	IBOutlet id <CQChatInputBarDelegate> delegate;
}
@property (nonatomic,assign) id <CQChatInputBarDelegate> delegate;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text;
@end
