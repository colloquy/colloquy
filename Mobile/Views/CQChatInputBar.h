#import "CQTextCompletionView.h"

@protocol CQChatInputBarDelegate;
@class CQTextCompletionView;

@interface CQChatInputBar : UIView <UITextViewDelegate, CQTextCompletionViewDelegate> {
	@protected
	UIToolbar *_backgroundView;
	UITextView *_inputView;
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
	UIViewAnimationCurve _animationCurve;
	NSTimeInterval _animationDuration;
	BOOL _showingKeyboard;
	UIButton *_accessoryButton;
	CGFloat _previousContentHeight;
	UIImageView *_overlayBackgroundView;
	UIImageView *_overlayBackgroundViewPiece;
	BOOL _shouldAnimateLayout;
}
@property (nonatomic, assign) id <CQChatInputBarDelegate> delegate;

@property (nonatomic, retain) UIColor *tintColor;

@property (nonatomic) BOOL autocomplete;
@property (nonatomic) BOOL spaceCyclesCompletions;
@property (nonatomic) BOOL autocorrect;

@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly) NSRange caretRange;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;

@property (nonatomic, readonly, getter=isShowingCompletions) BOOL showingCompletions;

- (void) showCompletionsForText:(NSString *) text inRange:(NSRange) range;
- (void) hideCompletions;

@property (nonatomic, copy) UIImage *accessoryView;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldIndent:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word;
- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range;
- (void) chatInputBarAccessoryButtonPressed:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldChangeHeightBy:(CGFloat) difference;
@end
