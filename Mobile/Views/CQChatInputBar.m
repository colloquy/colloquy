#import "CQChatInputBar.h"

#import "CQTextCompletionView.h"
#import "NSStringAdditions.h"

@interface UIKeyboardImpl : UIView
+ (UIKeyboardImpl *) activeInstance;
- (void) takeTextInputTraitsFrom:(id <UITextInputTraits>) object;
- (void) updateReturnKey:(BOOL) update;
@end

#pragma mark -

@interface UITextField (UITextFieldPrivate)
@property (nonatomic) NSRange selectionRange;
- (BOOL) hasMarkedText;
@end

#pragma mark -

@interface CQChatInputBar (CQChatInputBarPrivate)
- (void) _updateTextTraits;
@end

#pragma mark -

@implementation CQChatInputBar
- (void) _commonInitialization {
	CGRect frame = self.frame;

	_inputField = [[UITextField alloc] initWithFrame:CGRectMake(6., 6., frame.size.width - 12., frame.size.height - 14.)];
	_inputField.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	_inputField.borderStyle = UITextBorderStyleRoundedRect;
	_inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_inputField.adjustsFontSizeToFitWidth = YES;
	_inputField.minimumFontSize = 10.;
	_inputField.returnKeyType = UIReturnKeySend;
	_inputField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_inputField.enablesReturnKeyAutomatically = YES;
	_inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
	_inputField.delegate = self;

	[self addSubview:_inputField];

	_inferAutocapitalizationType = YES;
	_autocomplete = YES;
	_autocorrect = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideCompletions) name:UIDeviceOrientationDidChangeNotification object:nil]; 
}

#pragma mark -

- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_inputField release];
	[_completionView release];

	[super dealloc];
}

#pragma mark -

- (void) drawRect:(CGRect) rect {
	static UIImage *backgroundImage;
	if (!backgroundImage)
		backgroundImage = [[[UIImage imageNamed:@"chatInputBarBackground.png"] stretchableImageWithLeftCapWidth:0. topCapHeight:2.] retain];
	[backgroundImage drawInRect:self.bounds];
}

- (BOOL) canBecomeFirstResponder {
	return [_inputField canBecomeFirstResponder];
}

- (BOOL) becomeFirstResponder {
	return [_inputField becomeFirstResponder];
}

- (BOOL) canResignFirstResponder {
	return [_inputField canResignFirstResponder];
}

- (BOOL) resignFirstResponder {
	return [_inputField resignFirstResponder];
}

- (BOOL) isFirstResponder {
	return [_inputField isFirstResponder];
}

- (UITextAutocapitalizationType) autocapitalizationType {
	return _inputField.autocapitalizationType;
}

- (void) setAutocapitalizationType:(UITextAutocapitalizationType) autocapitalizationType {
	_inputField.autocapitalizationType = autocapitalizationType;
}

@synthesize inferAutocapitalizationType = _inferAutocapitalizationType;

@synthesize autocomplete = _autocomplete;

@synthesize autocorrect = _autocorrect;

#pragma mark -

- (BOOL) isShowingCompletions {
	return (_completionView && !_completionView.hidden);
}

- (void) hideCompletions {
	if (!_completionView)
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];

	_completionView.hidden = YES;

	[_completionView removeFromSuperview];
	[_completionView release];
	_completionView = nil;

	_inputField.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];
}

- (void) showCompletions {
	if (!_completionView)
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];

	BOOL hasMarkedText = ([_inputField respondsToSelector:@selector(hasMarkedText)] && [_inputField hasMarkedText]);
	_completionView.hidden = hasMarkedText;

	[_completionView.superview bringSubviewToFront:_completionView];

	if (_completionView.hidden) _inputField.returnKeyType = UIReturnKeySend;
	else _inputField.returnKeyType = UIReturnKeyDefault;

	[self _updateTextTraits];
}

- (void) showCompletions:(NSArray *) completions forText:(NSString *) text inRange:(NSRange) textRange {
	if (!_completionView) {
		_completionView = [[CQTextCompletionView alloc] initWithFrame:CGRectMake(0., 0., 480., 46.)];
		_completionView.delegate = self;
		_completionView.hidden = YES;

		[self.superview addSubview:_completionView];
	}

	CGRect inputFrame = [self convertRect:_inputField.frame toView:self.superview];
	NSString *prefixText = [text substringToIndex:textRange.location];
	CGSize textSize = [prefixText sizeWithFont:_inputField.font];
	CGRect frame = _completionView.frame;

retry:
	_completionView.completions = completions;
	[_completionView sizeToFit];

	_completionRange = textRange;

	frame.origin = inputFrame.origin;
	frame.origin.y -= 31.;
	frame.origin.x += textSize.width + 1.;

	if ((frame.origin.x + _completionView.bounds.size.width) > CGRectGetMaxX(inputFrame))
		frame.origin.x -= ((frame.origin.x + _completionView.bounds.size.width) - CGRectGetMaxX(inputFrame));

	if (frame.origin.x < inputFrame.origin.x) {
		if (completions.count > 1) {
			completions = [completions subarrayWithRange:NSMakeRange(0, (completions.count - 1))];
			goto retry;
		} else {
			[self hideCompletions];
			return;
		}
	}

	_completionView.frame = frame;

	_inputField.returnKeyType = UIReturnKeyDefault;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];

	[self performSelector:@selector(showCompletions) withObject:nil afterDelay:0.05];
}

#pragma mark -

@synthesize delegate;

- (BOOL) textFieldShouldBeginEditing:(UITextField *) textField {
	if ([delegate respondsToSelector:@selector(chatInputBarShouldBeginEditing:)])
		return [delegate chatInputBarShouldBeginEditing:self];
	return YES;
}

- (void) textFieldDidBeginEditing:(UITextField *) textField {
	if ([delegate respondsToSelector:@selector(chatInputBarDidBeginEditing:)])
		[delegate chatInputBarDidBeginEditing:self];
}

- (BOOL) textFieldShouldEndEditing:(UITextField *) textField {
	if ([delegate respondsToSelector:@selector(chatInputBarShouldEndEditing:)])
		return [delegate chatInputBarShouldEndEditing:self];
	return YES;
}

- (void) textFieldDidEndEditing:(UITextField *) textField {
	if ([delegate respondsToSelector:@selector(chatInputBarDidEndEditing:)])
		[delegate chatInputBarDidEndEditing:self];
	[self hideCompletions];
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	if (self.showingCompletions) {
		[_completionView retain];

		if (_completionView.selectedCompletion != NSNotFound)
			[self textCompletionView:_completionView didSelectCompletion:[_completionView.completions objectAtIndex:_completionView.selectedCompletion]];
		else [self hideCompletions];

		[_completionView release];
		return YES;
	}

	if (![delegate respondsToSelector:@selector(chatInputBar:sendText:)])
		return NO;

	if (!_inputField.text.length)
		return NO;

	// Perform work on a delay so pending auto-corrections can be committed.
	[self performSelector:@selector(_sendText) withObject:nil afterDelay:0.];

	return YES;
}

- (BOOL) textFieldShouldClear:(UITextField *) textField {
	_inputField.autocorrectionType = (_autocorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo);

	[self _updateTextTraits];
	[self hideCompletions];

	return YES;
}

- (BOOL) textField:(UITextField *) textField shouldChangeCharactersInRange:(NSRange) range replacementString:(NSString *) string {
	if (![delegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![delegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:)])
		return YES;

	NSString *text = _inputField.text;

	if (self.showingCompletions && [string isEqualToString:@" "]) {
		if (_completionView.closeSelected) {
			[self hideCompletions];
			return NO;
		} else if (text.length > (range.location - 1) && [text characterAtIndex:(range.location - 1)] == ' ' && !_completionView.closeSelected) {
			if (_completionView.selectedCompletion != NSNotFound)
				++_completionView.selectedCompletion;
			else _completionView.selectedCompletion = 0;
			return NO;
		}
	}

	NSRange wordRange = {0, range.location + string.length};
	text = [text stringByReplacingCharactersInRange:range withString:string];

	BOOL foundCharacter = NO;
	for (NSInteger i = (range.location + string.length - 1); i >= 0; --i) {
		if ([text characterAtIndex:i] == ' ' && foundCharacter) {
			wordRange.location = i + 1;
			wordRange.length = ((range.location + string.length) - wordRange.location);
			break;
		}

		foundCharacter = YES;
	}

	NSString *word = [[text substringWithRange:wordRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	BOOL hasMarkedText = ([_inputField respondsToSelector:@selector(hasMarkedText)] && [_inputField hasMarkedText]);

	NSArray *completions = nil;
	if (_autocomplete && word.length && !hasMarkedText && [delegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:inRange:)]) {
		completions = [delegate chatInputBar:self completionsForWordWithPrefix:word inRange:wordRange];
		if (completions.count)
			[self showCompletions:completions forText:text inRange:wordRange];
		 else [self hideCompletions];
	} else [self hideCompletions];

	wordRange.location = 0;
	wordRange.length = (range.location + string.length);

	for (NSInteger i = (range.location + string.length - 1); i >= 0; --i) {
		if ([text characterAtIndex:i] == ' ') {
			wordRange.location = i + 1;
			wordRange.length = ((range.location + string.length) - wordRange.location);
			break;
		}
	}

	word = [text substringWithRange:wordRange];

	UITextAutocorrectionType newAutocorrectionType = _inputField.autocorrectionType;
	if (!_autocorrect || completions.count || ([delegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![delegate chatInputBar:self shouldAutocorrectWordWithPrefix:word]))
		newAutocorrectionType = UITextAutocorrectionTypeNo;
	else newAutocorrectionType = UITextAutocorrectionTypeDefault;

	if (newAutocorrectionType != _inputField.autocorrectionType) {
		_inputField.autocorrectionType = newAutocorrectionType;
		[self _updateTextTraits];
	}

	return YES;
}

- (void) textFieldEditorDidChangeSelection:(UITextField *) textField {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];

	[self performSelector:@selector(hideCompletions) withObject:nil afterDelay:0.1];
}

#pragma mark -

- (void) textCompletionView:(CQTextCompletionView *) textCompletionView didSelectCompletion:(NSString *) completion {
	[self hideCompletions];

	if (![completion hasSuffix:@" "])
		completion = [completion stringByAppendingString:@" "];

	NSString *text = _inputField.text;
	if (text.length > (NSMaxRange(_completionRange) + 1) && [text characterAtIndex:NSMaxRange(_completionRange)] == ' ')
		++_completionRange.length;

	_inputField.text = [text stringByReplacingCharactersInRange:_completionRange withString:completion];

	if ([_inputField respondsToSelector:@selector(setSelectionRange:)])
		_inputField.selectionRange = NSMakeRange((_completionRange.location + completion.length), 0);
}

- (void) textCompletionViewDidClose:(CQTextCompletionView *) textCompletionView {
	[self hideCompletions];
}

#pragma mark -

- (void) _updateTextTraits {
	static Class keyboardClass;
	if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");

	if ([keyboardClass respondsToSelector:@selector(activeInstance)]) {
		UIKeyboardImpl *keyboard = [keyboardClass activeInstance];
		if ([keyboard respondsToSelector:@selector(takeTextInputTraitsFrom:)])
			[keyboard takeTextInputTraitsFrom:_inputField];
		if ([keyboard respondsToSelector:@selector(updateReturnKey:)])
			[keyboard updateReturnKey:YES];
	}
}

- (void) _sendText {
	// Resign and become first responder to accept any pending auto-correction.
	[_inputField resignFirstResponder];
	[_inputField becomeFirstResponder];

	NSString *text = _inputField.text;
	text = [text stringBySubstitutingEmojiForEmoticons];

	if (![delegate chatInputBar:self sendText:text])
		return;

	if (_inferAutocapitalizationType) {
		unichar firstCharacter = [text characterAtIndex:0];
		NSCharacterSet *letterSet = [NSCharacterSet letterCharacterSet];
		if ([letterSet characterIsMember:firstCharacter]) {
			NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
			if ([uppercaseSet characterIsMember:firstCharacter])
				_inputField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
			else _inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		}
	}

	_inputField.text = @"";
	_inputField.autocorrectionType = (_autocorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo);

	[self _updateTextTraits];
	[self hideCompletions];
}
@end
