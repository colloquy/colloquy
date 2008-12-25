@protocol CQChatInputBarDelegate;

@interface CQChatInputBar : UIView <UITextFieldDelegate> {
	UITextField *_inputField;
	BOOL _inferAutocapitalizationType;
	IBOutlet id <CQChatInputBarDelegate> delegate;
}
@property (nonatomic,assign) id <CQChatInputBarDelegate> delegate;

@property (nonatomic) BOOL inferAutocapitalizationType;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word;
@end
