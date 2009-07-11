#import "CQTextCompletionView.h"

@protocol CQChatInputBarDelegate;
@class CQTextCompletionView;

@interface CQChatInputBar : UIView <UITextFieldDelegate, CQTextCompletionViewDelegate> {
	@protected
	UIToolbar *_backgroundView;
	UITextField *_inputField;
	IBOutlet id <CQChatInputBarDelegate> delegate;
	CQTextCompletionView *_completionView;
	NSArray *_completions;
	NSRange _completionRange;
	BOOL _completionCapturedKeyboard;
	BOOL _disableCompletionUntilNextWord;
	BOOL _autocomplete;
	BOOL _spaceCyclesCompletions;
	BOOL _autocorrect;
	BOOL _autocapitalizeNextLetter;
	UITextAutocapitalizationType _defaultAutocapitalizationType;
}
@property (nonatomic, assign) id <CQChatInputBarDelegate> delegate;

@property (nonatomic, retain) UIColor *tintColor;

@property (nonatomic) BOOL autocomplete;
@property (nonatomic) BOOL spaceCyclesCompletions;
@property (nonatomic) BOOL autocorrect;

@property (nonatomic, readonly) UITextField *textField;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;

@property (nonatomic, readonly, getter=isShowingCompletions) BOOL showingCompletions;

- (void) hideCompletions;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word;
- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range;
@end
