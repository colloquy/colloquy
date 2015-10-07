#import "CQTextCompletionView.h"
#import "MVChatString.h"

@protocol CQChatInputBarDelegate;

typedef NS_ENUM(NSInteger, CQChatInputBarResponderState) {
	CQChatInputBarNotResponder,
	CQChatInputBarResponder
};

NS_ASSUME_NONNULL_BEGIN

@interface CQChatInputBar : UIView
@property (nonatomic, nullable, weak) IBOutlet id <CQChatInputBarDelegate> delegate;

@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIFont *font;

@property (nonatomic) BOOL autocomplete;
@property (nonatomic) BOOL spaceCyclesCompletions;
@property (nonatomic) BOOL autocorrect;

@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly) NSRange caretRange;
@property (nonatomic, readonly) UIButton *accessoryButton;

@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;

@property (nonatomic, readonly, getter=isShowingCompletions) BOOL showingCompletions;

- (void) showCompletionsForText:(NSString *) text inRange:(NSRange) range;
- (void) hideCompletions;

- (void) updateTextViewContentSize;

- (void) setAccessoryImage:(UIImage *) image forResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState;
- (UIImage *) accessoryImageForResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (void) chatInputBarTextDidChange:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldIndent:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidChangeSelection:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(MVChatString *) text;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word;
- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range;
- (void) chatInputBarAccessoryButtonPressed:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldChangeHeightBy:(CGFloat) difference;
@end

NS_ASSUME_NONNULL_END
