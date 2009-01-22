#import "CQChatInputBar.h"

#import "CQTextCompletionView.h"
#import "NSStringAdditions.h"

#define CompletionsCaptureKeyboardDelay 0.5

#ifdef ENABLE_SECRETS
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
#endif

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

	_autocomplete = YES;

#ifdef ENABLE_SECRETS
	_inputField.autocorrectionType = UITextAutocorrectionTypeDefault;
	_autocorrect = YES;
#else
	_inputField.autocorrectionType = UITextAutocorrectionTypeNo;
	_autocorrect = NO;
#endif

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
	[_completions release];

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

@synthesize autocomplete = _autocomplete;

@synthesize spaceCyclesCompletions = _spaceCyclesCompletions;

@synthesize autocorrect = _autocorrect;

#ifdef ENABLE_SECRETS
- (void) setAutocorrect:(BOOL) autocorrect {
	// Do nothing, autocorrection can't be enabled if we don't use secrets, since it would
	// appear over our completion popup and fight with the entered text.
}
#endif

#pragma mark -

@synthesize textField = _inputField;

- (BOOL) isShowingCompletions {
	return (_completionView && !_completionView.hidden);
}

- (void) captureKeyboardForCompletions {
	_completionCapturedKeyboard = YES;

	if (self.showingCompletions) _inputField.returnKeyType = UIReturnKeyDefault;
	else _inputField.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];
}

- (void) hideCompletions {
	_completionCapturedKeyboard = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(captureKeyboardForCompletions) object:nil];

	_completionRange = NSMakeRange(NSNotFound, 0);

	id old = _completions;
	_completions = nil;
	[old release];

	_completionView.hidden = YES;
	_completionView.completions = nil;

	_inputField.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];
}

- (void) showCompletions {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];

#ifdef ENABLE_SECRETS
	if ([_inputField respondsToSelector:@selector(hasMarkedText)] && [_inputField hasMarkedText]) {
		[self hideCompletions];
		return;
	}
#endif

	NSString *text = _inputField.text;
	if (text.length <= _completionRange.location) {
		[self hideCompletions];
		return;
	}

	if (!_completionView) {
		_completionView = [[CQTextCompletionView alloc] initWithFrame:CGRectMake(0., 0., 480., 46.)];
		_completionView.delegate = self;
		_completionView.hidden = YES;

		[self.superview addSubview:_completionView];
	}

	NSArray *completions = _completions;
	NSString *prefixText = [text substringToIndex:_completionRange.location];
	CGSize textSize = [prefixText sizeWithFont:_inputField.font];

	CGRect inputFrame = [self convertRect:_inputField.frame toView:self.superview];
	CGRect frame = _completionView.frame;

retry:
	_completionView.completions = completions;
	[_completionView sizeToFit];

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
	_completionView.hidden = NO;

	[_completionView.superview bringSubviewToFront:_completionView];
}

- (void) showCompletions:(NSArray *) completions forText:(NSString *) text inRange:(NSRange) textRange {
	_completionRange = textRange;

	id old = _completions;
	_completions = [completions retain];
	[old release];

	_inputField.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(captureKeyboardForCompletions) object:nil];

	[self performSelector:@selector(showCompletions) withObject:nil afterDelay:([self isShowingCompletions] ? 0.05 : 0.1)];

	if (_spaceCyclesCompletions)
		[self performSelector:@selector(captureKeyboardForCompletions) withObject:nil afterDelay:CompletionsCaptureKeyboardDelay];
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
	if (_completionCapturedKeyboard && self.showingCompletions) {
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
	_disableCompletionUntilNextWord = NO;
	_completionCapturedKeyboard = NO;

	_inputField.autocorrectionType = (_autocorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo);

	[self _updateTextTraits];
	[self hideCompletions];

	return YES;
}

- (BOOL) textField:(UITextField *) textField shouldChangeCharactersInRange:(NSRange) range replacementString:(NSString *) string {
	if (_autocapitalizeNextLetter) {
		_autocapitalizeNextLetter = NO;
		_inputField.autocapitalizationType = _defaultAutocapitalizationType;
		[self _updateTextTraits];
	}

	if (![delegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![delegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:)])
		return YES;

	if (_spaceCyclesCompletions && _completionCapturedKeyboard && self.showingCompletions && [string isEqualToString:@" "] && !_completionView.closeSelected) {
		if (_completionView.selectedCompletion != NSNotFound)
			++_completionView.selectedCompletion;
		else _completionView.selectedCompletion = 0;
		return NO;
	}

	_completionCapturedKeyboard = NO;

	NSString *text = _inputField.text;
	BOOL replaceManually = NO;
	if (_spaceCyclesCompletions && self.showingCompletions && _completionView.selectedCompletion != NSNotFound && !range.length && ![string isEqualToString:@" "]) {
		replaceManually = YES;
		text = [_inputField.text stringByReplacingCharactersInRange:NSMakeRange(range.location, 0) withString:@" "];
		++range.location;
	}

	NSRange wordRange = {0, range.location + string.length};
	text = [text stringByReplacingCharactersInRange:range withString:string];

	for (NSInteger i = (range.location + string.length - 1); i >= 0; --i) {
		if ([text characterAtIndex:i] == ' ') {
			wordRange.location = i + 1;
			wordRange.length = ((range.location + string.length) - wordRange.location);
			break;
		}
	}

	if (!wordRange.length)
		_disableCompletionUntilNextWord = NO;

	NSString *word = [text substringWithRange:wordRange];
#ifdef ENABLE_SECRETS
	BOOL hasMarkedText = ([_inputField respondsToSelector:@selector(hasMarkedText)] && [_inputField hasMarkedText]);
#else
	BOOL hasMarkedText = NO;
#endif

	NSArray *completions = nil;
	if (_autocomplete && !_disableCompletionUntilNextWord && word.length && !hasMarkedText && [delegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:inRange:)]) {
		completions = [delegate chatInputBar:self completionsForWordWithPrefix:word inRange:wordRange];
		if (completions.count)
			[self showCompletions:completions forText:text inRange:wordRange];
		 else [self hideCompletions];
	} else [self hideCompletions];

	word = [text substringWithRange:wordRange];

	UITextAutocorrectionType newAutocorrectionType = _inputField.autocorrectionType;
	if (!_autocorrect || completions.count || ([delegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![delegate chatInputBar:self shouldAutocorrectWordWithPrefix:word]))
		newAutocorrectionType = UITextAutocorrectionTypeNo;
	else newAutocorrectionType = UITextAutocorrectionTypeDefault;

	if (newAutocorrectionType != _inputField.autocorrectionType) {
		_inputField.autocorrectionType = newAutocorrectionType;
		[self _updateTextTraits];
	}

	if (replaceManually) {
		_inputField.text = text;
#ifdef ENABLE_SECRETS
		if ([_inputField respondsToSelector:@selector(setSelectionRange:)])
			_inputField.selectionRange = NSMakeRange((range.location + string.length), 0);
#endif
		return NO;
	}

	return YES;
}

- (void) textFieldEditorDidChangeSelection:(UITextField *) textField {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];

	[self performSelector:@selector(hideCompletions) withObject:nil afterDelay:0.25];
}

#pragma mark -

- (void) textCompletionView:(CQTextCompletionView *) textCompletionView didSelectCompletion:(NSString *) completion {
	BOOL endsInPunctuation = (completion.length && [[NSCharacterSet punctuationCharacterSet] characterIsMember:[completion characterAtIndex:(completion.length - 1)]]);
	if (![completion hasSuffix:@" "])
		completion = [completion stringByAppendingString:@" "];

	NSString *text = _inputField.text;
	if (text.length >= (NSMaxRange(_completionRange) + 1) && [text characterAtIndex:NSMaxRange(_completionRange)] == ' ')
		++_completionRange.length;

	_inputField.text = [text stringByReplacingCharactersInRange:_completionRange withString:completion];

#ifdef ENABLE_SECRETS
	if ([_inputField respondsToSelector:@selector(setSelectionRange:)])
		_inputField.selectionRange = NSMakeRange((_completionRange.location + completion.length), 0);
#endif

	if (_completionRange.location == 0 && endsInPunctuation && _inputField.autocapitalizationType == UITextAutocapitalizationTypeSentences) {
		_autocapitalizeNextLetter = YES;
		_defaultAutocapitalizationType = UITextAutocapitalizationTypeSentences;
		_inputField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
		[self _updateTextTraits];
	}

	[self hideCompletions];
}

- (void) textCompletionViewDidClose:(CQTextCompletionView *) textCompletionView {
	NSString *text = _inputField.text;
	if (text.length < NSMaxRange(_completionRange) || [text characterAtIndex:(NSMaxRange(_completionRange) - 1)] != ' ')
		_disableCompletionUntilNextWord = YES;

	[self hideCompletions];
}

#pragma mark -

- (void) _updateTextTraits {
#ifdef ENABLE_SECRETS
	static Class keyboardClass;
	if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");

	if ([keyboardClass respondsToSelector:@selector(activeInstance)]) {
		UIKeyboardImpl *keyboard = [keyboardClass activeInstance];
		if ([keyboard respondsToSelector:@selector(takeTextInputTraitsFrom:)])
			[keyboard takeTextInputTraitsFrom:_inputField];
		if ([keyboard respondsToSelector:@selector(updateReturnKey:)])
			[keyboard updateReturnKey:YES];
	}
#endif
}

- (void) _sendText {
	// Resign and become first responder to accept any pending auto-correction.
	[_inputField resignFirstResponder];
	[_inputField becomeFirstResponder];

	NSString *text = _inputField.text;
	text = [text stringBySubstitutingEmojiForEmoticons];

	if (![delegate chatInputBar:self sendText:text])
		return;

	_disableCompletionUntilNextWord = NO;
	_completionCapturedKeyboard = NO;

	_inputField.text = @"";
	_inputField.autocorrectionType = (_autocorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo);

	[self _updateTextTraits];
	[self hideCompletions];
}
@end
