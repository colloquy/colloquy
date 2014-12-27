#import "CQChatInputBar.h"

#import "CQTextCompletionView.h"

#define CompletionsCaptureKeyboardDelay 0.5

static BOOL hardwareKeyboard;

#pragma mark -

@interface CQChatInputBar (CQChatInputBarPrivate)
- (void) _moveCaretToOffset:(NSUInteger) offset;
- (BOOL) _hasMarkedText;
- (void) _updateTextTraits;
@end

#pragma mark -

@implementation CQChatInputBar
@synthesize delegate = _delegate;

- (void) _commonInitialization {
	CGRect frame = self.bounds;
	frame.size.height += 1;

	self.backgroundColor = [UIColor clearColor];

	_backgroundView = [[UIInputView alloc] initWithFrame:frame inputViewStyle:UIInputViewStyleKeyboard];
	_backgroundView.tintColor = [UIColor colorWithWhite:(247. / 255.) alpha:1.];

	_topLineView = [[UIView alloc] initWithFrame:CGRectZero];
	_topLineView.backgroundColor = [UIColor colorWithWhite:(172. / 255.) alpha:1.];
	_backgroundView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);

	[self addSubview:_backgroundView];
	[self addSubview:_topLineView];

	if ([UIDevice currentDevice].isRetina)
		frame = CGRectMake(6.5, 6.5, frame.size.width - 12., frame.size.height - 12.);
	else frame = CGRectMake(6., 7., frame.size.width - 12., frame.size.height - 12.);

	_inputView = [[UITextView alloc] initWithFrame:frame];
	_inputView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	_inputView.contentSize = CGSizeMake(230., self._lineHeight);
	_inputView.dataDetectorTypes = UIDataDetectorTypeNone;
	_inputView.returnKeyType = UIReturnKeySend;
	_inputView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_inputView.enablesReturnKeyAutomatically = YES;
	_inputView.delegate = self;
	_inputView.backgroundColor = [UIColor clearColor];
	_inputView.font = [UIFont systemFontOfSize:16.];
	_inputView.textColor = [UIColor blackColor];
	_inputView.scrollEnabled = NO;

	_inputView.layer.borderColor = [UIColor colorWithRed:(200. / 255.) green:(200. / 255.) blue:(205. / 255.) alpha:1.].CGColor;
	if ([UIDevice currentDevice].isRetina)
		_inputView.layer.borderWidth = .5;
	else _inputView.layer.borderWidth = 1.;
	_inputView.layer.backgroundColor = [UIColor colorWithWhite:(250. / 255.) alpha:1.].CGColor;
	_inputView.layer.cornerRadius = 5.;
	[self addSubview:_inputView];

	_autocomplete = YES;

#if ENABLE(SECRETS)
	_inputView.autocorrectionType = UITextAutocorrectionTypeDefault;
#else
	_inputView.autocorrectionType = UITextAutocorrectionTypeNo;
	_autocorrect = NO;
#endif

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideCompletions) name:UIDeviceOrientationDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

	_accessoryButton = [UIButton buttonWithType:UIButtonTypeCustom];

	[_accessoryButton addTarget:self action:@selector(accessoryButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

	[self addSubview:_accessoryButton];

	_accessoryImages = [[NSMutableDictionary alloc] init];
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

	_inputView.delegate = nil;
	_completionView.delegate = nil;
}

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	[super canBecomeFirstResponder];
	return [_inputView canBecomeFirstResponder];
}

- (BOOL) becomeFirstResponder {
	[super becomeFirstResponder];
	return [_inputView becomeFirstResponder];
}

- (BOOL) canResignFirstResponder {
	[super canResignFirstResponder];
	return [_inputView canResignFirstResponder];
}

- (BOOL) resignFirstResponder {
	[super resignFirstResponder];
	return [_inputView resignFirstResponder];
}

- (BOOL) isFirstResponder {
	[super isFirstResponder];
	return [_inputView isFirstResponder];
}

- (BOOL) canPerformAction:(SEL) action withSender:(id) sender {
	[self hideCompletions];
	return NO;
}

- (void) setAccessoryImage:(UIImage *) image forResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState {
	NSMutableDictionary *responderStateDictionary = _accessoryImages[@(responderState)];
	if (!responderStateDictionary) {
		responderStateDictionary = [NSMutableDictionary dictionary];

		_accessoryImages[@(responderState)] = responderStateDictionary;
	}

	responderStateDictionary[@(controlState)] = image;

	if (responderState == _responderState) {
		[self _updateImagesForResponderState];

		[self setNeedsLayout];
	}
}

- (UIImage *) accessoryImageForResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState {
	return _accessoryImages[@(responderState)][@(controlState)];
}

- (UITextAutocapitalizationType) autocapitalizationType {
	return _inputView.autocapitalizationType;
}

- (void) setAutocapitalizationType:(UITextAutocapitalizationType) autocapitalizationType {
	_inputView.autocapitalizationType = autocapitalizationType;
}

#if !ENABLE(SECRETS)
- (void) setAutocorrect:(BOOL) autocorrect {
	// Do nothing, autocorrection can't be enabled if we don't use secrets, since it would
	// appear over our completion popup and fight with the entered text.
}
#endif

- (NSRange) caretRange {
	return _inputView.selectedRange;
}

- (void) setHeight:(CGFloat) height numberOfLines:(NSUInteger) numberOfLines {
	if (height == CGRectGetHeight(self.frame))
		return;

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	BOOL shouldSetHeight = YES;
	if (strongDelegate && [strongDelegate respondsToSelector:@selector(chatInputBar:shouldChangeHeightBy:)])
		shouldSetHeight = [strongDelegate chatInputBar:self shouldChangeHeightBy:(self.frame.size.height - height)];

	if (shouldSetHeight) {
		self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, height);

		[self setNeedsLayout];
		[self layoutIfNeeded];

		// Work around iOS 7 bug where the input view frame doesn't update right away after being set, causing text to be clipped.
		_inputView.frame = _inputView.frame;
		_inputView.contentSize = CGSizeMake(floorf((_inputView.frame.size.width - (_inputView.frame.origin.x * 2))), ((numberOfLines + 1) * self._lineHeight));
	}
}

- (UIColor *) tintColor {
	return _backgroundView.tintColor;
}

- (void) setTintColor:(UIColor *) color {
	if (!color) {
		color = [UIColor colorWithWhite:(247. / 255.) alpha:1.];
	} else if ([color isEqual:[UIColor blackColor]]) {
		color = [UIColor colorWithWhite:(43. / 255.) alpha:1.];
	}

	if ([color isEqual:[UIColor blackColor]] || [color isEqual:[UIColor colorWithWhite:(43. / 255.) alpha:1.]]) {
		_inputView.keyboardAppearance = UIKeyboardAppearanceDark;
		_backgroundView.backgroundColor = [UIColor colorWithWhite:(43. / 255.) alpha:1.];
	} else {
		_inputView.keyboardAppearance = UIKeyboardAppearanceLight;
		_backgroundView.backgroundColor = [UIColor colorWithWhite:(247. / 255.) alpha:1.];
	}

	self.backgroundColor = color;
}

- (UIFont *) font {
	return _inputView.font;
}

- (void) setFont:(UIFont *) font {
	if (font.pointSize > .0)
		_inputView.font = font;

	[self _resetTextViewHeight];
}

#pragma mark -

@synthesize textView = _inputView;

- (BOOL) isShowingCompletions {
	return (_completionView && !_completionView.hidden);
}

- (void) captureKeyboardForCompletions {
	_completionCapturedKeyboard = YES;

	if (self.showingCompletions) _inputView.returnKeyType = UIReturnKeyDefault;
	else _inputView.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];
}

- (void) showCompletionsForText:(NSString *) text inRange:(NSRange) range {
	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if (![strongDelegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:inRange:)])
		return;

	NSArray *completions = [strongDelegate chatInputBar:self completionsForWordWithPrefix:text inRange:range];
	if (completions.count)
		[self showCompletions:completions forText:text inRange:range];
	else [self hideCompletions];
}

- (void) hideCompletions {
	_completionCapturedKeyboard = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(captureKeyboardForCompletions) object:nil];

	_completionRange = NSMakeRange(NSNotFound, 0);

	_completions = nil;

	_completionView.hidden = YES;
	_completionView.completions = nil;

	_inputView.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];
}

- (void) showCompletions {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];

	if ([self _hasMarkedText]) {
		[self hideCompletions];
		return;
	}

	NSString *text = _inputView.text;
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
	CGSize textSize = [prefixText sizeWithAttributes:@{ NSFontAttributeName: _inputView.font }];

	CGRect inputFrame = [self convertRect:_inputView.frame toView:self.superview];

retry:
	_completionView.completions = completions;
	[_completionView sizeToFit];

	CGRect frame = _completionView.frame;
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

	_completions = completions;

	_inputView.returnKeyType = UIReturnKeySend;

	[self _updateTextTraits];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCompletions) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(captureKeyboardForCompletions) object:nil];

	[self performSelector:@selector(showCompletions) withObject:nil afterDelay:([self isShowingCompletions] ? 0.05 : 0.15)];

	if (_spaceCyclesCompletions)
		[self performSelector:@selector(captureKeyboardForCompletions) withObject:nil afterDelay:CompletionsCaptureKeyboardDelay];
}

#pragma mark -

- (void) updateTextViewContentSize {
	if (_inputView.hasText && _inputView.text.length) {
		CGSize lineSize = [@"a" sizeWithAttributes:@{ NSFontAttributeName: _inputView.font }];

		NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

		CGFloat availableWidth = _inputView.contentSize.width - 5.;
		CGSize suggestedTextSize = [_inputView.text boundingRectWithSize:CGSizeMake(availableWidth, 90000) options:(NSStringDrawingOptions)NSStringDrawingUsesLineFragmentOrigin attributes:@{
			NSFontAttributeName: _inputView.font,
			NSParagraphStyleAttributeName: paragraphStyle
		} context:nil].size;

		CGFloat numberOfLines = roundf(suggestedTextSize.height / lineSize.height);
		CGFloat contentHeight = fminf((self._inactiveLineHeight + ((numberOfLines - 1) * self._lineHeight)), self._maxLineHeight);

		if (contentHeight < self._maxLineHeight)
			_inputView.scrollEnabled = NO;
		else _inputView.scrollEnabled = YES;
		[self setHeight:contentHeight numberOfLines:(numberOfLines - 1)];
	} else {
		[self _resetTextViewHeight];
	}
}

#pragma mark -

- (void) accessoryButtonPressed:(id) sender {
	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if (strongDelegate && [strongDelegate respondsToSelector:@selector(chatInputBarAccessoryButtonPressed:)])
		[strongDelegate chatInputBarAccessoryButtonPressed:self];
}

#pragma mark -

- (void) keyboardWillShow:(NSNotification *) notification {
	_responderState = CQChatInputBarResponder;

	_animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	_animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

	[self _updateImagesForResponderState];

	[self setNeedsLayout];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	_responderState = CQChatInputBarNotResponder;

	_animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	_animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

	[self _updateImagesForResponderState];

	[self setNeedsLayout];
}

- (void) scrollViewDidScroll:(UIScrollView *) scrollView {
	scrollView.contentOffset = CGPointMake(0.0, fmaxf(scrollView.contentInset.top, scrollView.contentOffset.y));
}

- (BOOL) textViewShouldBeginEditing:(UITextView *) textView {
	textView.contentInset = UIEdgeInsetsMake(-4., 2., 0., 0.);

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarShouldBeginEditing:)])
		return [strongDelegate chatInputBarShouldBeginEditing:self];
	return YES;
}

- (void) textViewDidBeginEditing:(UITextView *) textView {
	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarDidBeginEditing:)])
		[strongDelegate chatInputBarDidBeginEditing:self];
}

- (BOOL) textViewShouldEndEditing:(UITextView *) textView {
	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarShouldEndEditing:)])
		return [strongDelegate chatInputBarShouldEndEditing:self];
	return YES;
}

- (void) textViewDidEndEditing:(UITextView *) textView {
	textView.contentInset = UIEdgeInsetsMake(-4., 2., 0., 0.);

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarDidEndEditing:)])
		[strongDelegate chatInputBarDidEndEditing:self];
	[self hideCompletions];
}

- (BOOL) textViewShouldReturn:(UITextView *) textView {
	if (_completionCapturedKeyboard && self.showingCompletions) {
		if (_completionView.selectedCompletion != NSNotFound)
			[self textCompletionView:_completionView didSelectCompletion:_completionView.completions[_completionView.selectedCompletion]];
		else [self hideCompletions];

		return YES;
	}

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if (![strongDelegate respondsToSelector:@selector(chatInputBar:sendText:)])
		return NO;

	if (!_inputView.text.length)
		return NO;

	// Perform work on a delay so pending auto-corrections can be committed.
	[self performSelector:@selector(_sendText) withObject:nil afterDelay:0.];

	return YES;
}

- (BOOL) textView:(UITextView *) textView shouldChangeTextInRange:(NSRange) range replacementText:(NSString *) string {
	@synchronized(textView) {
		__strong __typeof__((_delegate)) strongDelegate = _delegate;

		if ([string isEqualToString:@"\n"]) {
			[self textViewShouldReturn:textView];

			return NO;
		}

		if ([string isEqualToString:@"\t"]) {
			hardwareKeyboard = YES;

			if ([strongDelegate respondsToSelector:@selector(chatInputBarShouldIndent:)] && ![strongDelegate chatInputBarShouldIndent:self])
				return NO;
		}

		if (_autocapitalizeNextLetter) {
			_autocapitalizeNextLetter = NO;
			_inputView.autocapitalizationType = _defaultAutocapitalizationType;
			[self _updateTextTraits];
		}

		if (![strongDelegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![strongDelegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:)])
			return YES;

		if (_spaceCyclesCompletions && _completionCapturedKeyboard && self.showingCompletions && [string isEqualToString:@" "] && !_completionView.closeSelected) {
			if (_completionView.selectedCompletion != NSNotFound)
				++_completionView.selectedCompletion;
			else _completionView.selectedCompletion = 0;
			return NO;
		}

		_completionCapturedKeyboard = NO;

		NSString *text = _inputView.text;
		BOOL replaceManually = NO;
		if (_spaceCyclesCompletions && self.showingCompletions && _completionView.selectedCompletion != NSNotFound && !range.length && ![string isEqualToString:@" "]) {
			replaceManually = YES;
			text = [_inputView.text stringByReplacingCharactersInRange:NSMakeRange(range.location, 0) withString:@" "];
			++range.location;
		}

		NSRange wordRange = {0, range.location + string.length};
		text = [text stringByReplacingCharactersInRange:range withString:string];

		for (NSInteger i = (range.location + string.length - 1); i >= 0; --i) {
			if (i > (NSInteger)text.length) {
				wordRange.length = 0;
				break;
			}

			if ([text characterAtIndex:i] == ' ') {
				wordRange.location = i + 1;
				wordRange.length = ((range.location + string.length) - wordRange.location);
				break;
			}
		}

		if (!wordRange.length)
			_disableCompletionUntilNextWord = NO;

		NSString *word = [[text substringWithRange:wordRange] copy];
		NSArray *completions = nil;
		BOOL canShowCompletionForCurrentWord = textView.text.length;
		if (canShowCompletionForCurrentWord) {
			if (!((range.location + range.length) == textView.text.length)) { // if we're in the middle of a line, only show completions if the next letter is a space
				NSUInteger idx = (range.location + range.length);
				if (textView.text.length > idx) {
					unichar character = [textView.text characterAtIndex:idx];
					canShowCompletionForCurrentWord = [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:character];
				}
			} else canShowCompletionForCurrentWord = YES; // if we are at the end of the line, we can show completions since there's nothing else after it
		} else canShowCompletionForCurrentWord = YES; // if we don't have any text, we can maybe show completions although we probably won't (not enough context yet)

		if (_autocomplete && canShowCompletionForCurrentWord && !_disableCompletionUntilNextWord && word.length && ![self _hasMarkedText] && [strongDelegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:inRange:)]) {
			@synchronized(strongDelegate) {
				completions = [strongDelegate chatInputBar:self completionsForWordWithPrefix:word inRange:wordRange];
			}
			if (completions.count)
				[self showCompletions:completions forText:text inRange:wordRange];
			 else [self hideCompletions];
		} else [self hideCompletions];

		word = [text substringWithRange:wordRange];

		UITextAutocorrectionType newAutocorrectionType = UITextAutocorrectionTypeDefault;
		if (!_autocorrect || completions.count || ([strongDelegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![strongDelegate chatInputBar:self shouldAutocorrectWordWithPrefix:word]))
			newAutocorrectionType = UITextAutocorrectionTypeNo;

		if (newAutocorrectionType != _inputView.autocorrectionType) {
			_inputView.autocorrectionType = newAutocorrectionType;
			[self _updateTextTraits];
		}

		if (replaceManually) {
			_inputView.text = text;
			[self _moveCaretToOffset:(range.location + string.length)];
			return NO;
		}

		return YES;
	}
}

- (void) textViewDidChange:(UITextView *) textView {
	[self updateTextViewContentSize];
	[self _updateImagesForResponderState];
}

- (void) textViewDidChangeSelection:(UITextView *) textView {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCompletions) object:nil];

	[self performSelector:@selector(hideCompletions) withObject:nil afterDelay:0.5];

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarDidChangeSelection:)])
		[strongDelegate chatInputBarDidChangeSelection:self];
}

#pragma mark -

- (void) textCompletionView:(CQTextCompletionView *) textCompletionView didSelectCompletion:(NSString *) completion {
	BOOL endsInPunctuation = (completion.length && [[NSCharacterSet punctuationCharacterSet] characterIsMember:[completion characterAtIndex:(completion.length - 1)]]);
	if (![completion hasSuffix:@" "])
		completion = [completion stringByAppendingString:@" "];

	NSString *text = _inputView.text;
	if (text.length >= (NSMaxRange(_completionRange) + 1) && [text characterAtIndex:NSMaxRange(_completionRange)] == ' ')
		++_completionRange.length;

	_inputView.text = [text stringByReplacingCharactersInRange:_completionRange withString:completion];
	[self _moveCaretToOffset:(_completionRange.location + completion.length)];

	if (_completionRange.location == 0 && endsInPunctuation && _inputView.autocapitalizationType == UITextAutocapitalizationTypeSentences) {
		_autocapitalizeNextLetter = YES;
		_defaultAutocapitalizationType = UITextAutocapitalizationTypeSentences;
		_inputView.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
		[self _updateTextTraits];
	}

	[self hideCompletions];
}

- (void) textCompletionViewDidClose:(CQTextCompletionView *) textCompletionView {
	NSString *text = _inputView.text;
	if (text.length < NSMaxRange(_completionRange) || [text characterAtIndex:(NSMaxRange(_completionRange) - 1)] != ' ')
		_disableCompletionUntilNextWord = YES;

	[self hideCompletions];
}

#pragma mark -

- (void) layoutSubviews {
	[super layoutSubviews];

	_backgroundView.frame = self.bounds;

	if ([UIDevice currentDevice].isRetina)
		_topLineView.frame = CGRectMake(0., 0., CGRectGetWidth(_backgroundView.frame), .5);
	else _topLineView.frame = CGRectMake(0., 0., CGRectGetWidth(_backgroundView.frame), 1.);
#define ButtonMargin 6.5
#define ButtonWidth 18.
	__block CGRect frame = _backgroundView.frame;
	if ([UIDevice currentDevice].isRetina)
		frame.size.width -= (ButtonWidth + ButtonMargin);
	else frame.size.width -= (ButtonWidth + floorf(ButtonMargin));
	_overlayBackgroundView.frame = frame;

	frame.origin.x = CGRectGetMaxX(frame);
	frame.size.width = CGRectGetWidth(self.frame) - CGRectGetMinX(frame);
	_overlayBackgroundViewPiece.frame = frame;

	[UIView animateWithDuration:_animationDuration delay:.0 options:(_animationCurve << 16) animations:^{
		frame = self.bounds;
		if ([UIDevice currentDevice].isRetina)
			frame = CGRectMake(6.5, 6.5, frame.size.width - 12., frame.size.height - 12.);
		else frame = CGRectMake(6., 7., frame.size.width - 12., frame.size.height - 12.);

		frame.size.width = _backgroundView.frame.size.width - (frame.origin.x * 2);
		if ([UIDevice currentDevice].isRetina)
			frame.size.width -= (ButtonWidth + ButtonMargin);
		else frame.size.width -= (ButtonWidth + floorf(ButtonMargin));

		frame.size.height = (self.frame.size.height - (17));
		frame.origin.y = (self.frame.size.height - frame.size.height) / 2.;
		_inputView.frame = frame;

		frame = _accessoryButton.frame;
		if ([UIDevice currentDevice].isRetina)
			frame.origin.x = CGRectGetMaxX(_inputView.frame) + ButtonMargin;
		else frame.origin.x = CGRectGetMaxX(_inputView.frame) + floorf(ButtonMargin);
		frame.origin.y = (ButtonMargin * 2);
		frame.size.width = ButtonWidth;
		frame.size.height = ButtonWidth;

		_accessoryButton.frame = frame;
#undef ButtonWidth
#undef ButtonMargin
	} completion:NULL];

	_animationDuration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
}

#pragma mark -

- (void) _moveCaretToOffset:(NSUInteger) offset {
	_inputView.selectedRange = NSMakeRange(offset, 0);
}

- (BOOL) _hasMarkedText {
	if (!_inputView.markedTextRange)
		return NO;
	return !_inputView.markedTextRange.empty;
}

- (void) _updateTextTraits {
	if ([UIDevice currentDevice].isSystemEight)
		return;

#if ENABLE(SECRETS)
	static Class keyboardClass;
	if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");

	NSAssert(keyboardClass, @"UIKeyboardImpl class does not exist.");

	__strong id keyboard = [keyboardClass performPrivateSelector:@"activeInstance"];
	if (!keyboard)
		return;

	static SEL takeTextInputTraitsFromDelegateSelector;
	if (!takeTextInputTraitsFromDelegateSelector)
		takeTextInputTraitsFromDelegateSelector = NSSelectorFromString(@"takeTextInputTraitsFromDelegate");

	static SEL takeTextInputTraitsFromSelector;
	if (!takeTextInputTraitsFromSelector)
		takeTextInputTraitsFromSelector = NSSelectorFromString(@"takeTextInputTraitsFrom:");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

	NSAssert([keyboard respondsToSelector:takeTextInputTraitsFromDelegateSelector] || [keyboard respondsToSelector:takeTextInputTraitsFromSelector], @"UIKeyboardImpl does not respond to takeTextInputTraitsFromDelegate or takeTextInputTraitsFrom:.");
	if ([keyboard respondsToSelector:takeTextInputTraitsFromDelegateSelector])
		[keyboard performSelector:takeTextInputTraitsFromDelegateSelector];
	else if ([keyboard respondsToSelector:takeTextInputTraitsFromSelector])
		[keyboard performSelector:takeTextInputTraitsFromSelector withObject:_inputView];

#pragma clang diagnostic pop
#endif
}

- (void) _sendText {
	@synchronized(_inputView) {
		// Resign and become first responder to accept any pending auto-correction.
		[_inputView resignFirstResponder];
		[_inputView becomeFirstResponder];

		MVChatString *text = _inputView.attributedText;
		if (!text) text = [[NSAttributedString alloc] initWithString:_inputView.text attributes:@{ NSFontAttributeName: _inputView.font }];
//		text = [text stringBySubstitutingEmojiForEmoticons];

		__strong __typeof__((_delegate)) strongDelegate = _delegate;
		if (![strongDelegate chatInputBar:self sendText:text])
			return;

		_disableCompletionUntilNextWord = NO;
		_completionCapturedKeyboard = NO;

		_inputView.text = @"";
		_inputView.autocorrectionType = (_autocorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo);

		[self hideCompletions];
		[self _resetTextViewHeight];
	}
}

- (void) _resetTextViewHeight {
	[self setHeight:self._inactiveLineHeight numberOfLines:0];

	_inputView.scrollEnabled = NO;
}

#pragma mark -

- (void) _updateImagesForResponderState {
	CQChatInputBarResponderState activeResponderState = _responderState;
	if (!_inputView.hasText)
	{
		activeResponderState = CQChatInputBarNotResponder;
	}

	UIImage *defaultImage = _accessoryImages[@(activeResponderState)][@(UIControlStateNormal)];
	if (defaultImage)
		[_accessoryButton setImage:defaultImage forState:UIControlStateNormal];

	UIImage *pressedImage = _accessoryImages[@(activeResponderState)][@(UIControlStateHighlighted)];
	if (pressedImage)
		[_accessoryButton setImage:pressedImage forState:UIControlStateHighlighted];
	else [_accessoryButton setImage:nil forState:UIControlStateHighlighted];
}

#pragma mark -

#define CQLineHeight 22.
#define CQInactiveLineHeight 44.
#define CQMaxLineHeight 84.

- (CGFloat) _lineHeight {
	if (!_inputView.font)
		return CQLineHeight;
	return fmaxf(CQLineHeight, [@"Jy" sizeWithAttributes:@{ NSFontAttributeName: _inputView.font }].height);
}

- (CGFloat) _inactiveLineHeight {
	return fmax(self._lineHeight * 2, CQInactiveLineHeight);
}

- (CGFloat) _maxLineHeight {
	return fmax(self._lineHeight * 4, CQMaxLineHeight);
}
@end
