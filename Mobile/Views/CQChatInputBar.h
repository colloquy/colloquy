#import "CQTextCompletionView.h"

@protocol CQChatInputBarDelegate;
@class CQTextCompletionView;

@interface CQChatInputBar : UIView <UITextFieldDelegate, CQTextCompletionViewDelegate> {
	UITextField *_inputField;
	BOOL _inferAutocapitalizationType;
	IBOutlet id <CQChatInputBarDelegate> delegate;
	CQTextCompletionView *_completionView;
	NSArray *_completions;
	NSRange _completionRange;
	BOOL _completionCapturedKeyboard;
	BOOL _disableCompletionUntilNextWord;
	BOOL _autocomplete;
	BOOL _autocorrect;
	BOOL _autocapitalizeNextLetter;
	UITextAutocapitalizationType _defaultAutocapitalizationType;
}
@property (nonatomic, assign) id <CQChatInputBarDelegate> delegate;

@property (nonatomic) BOOL autocomplete;
@property (nonatomic) BOOL autocorrect;

@property (nonatomic) BOOL inferAutocapitalizationType;
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
