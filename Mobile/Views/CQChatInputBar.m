#import "CQChatInputBar.h"

#import "CQTextView.h"

#import "UIColorAdditions.h"
#import "NSNotificationAdditions.h"

#define CompletionsCaptureKeyboardDelay 0.5
#define CQLineHeight 22.
#define CQInactiveLineHeight 44.
#define CQMaxLineHeight 84.
#define CQInputBarVerticalPadding 17.

#if SYSTEM(MAC)
static BOOL hardwareKeyboard = YES;
#else
static BOOL hardwareKeyboard;
#endif

static BOOL boldText;
static BOOL underlineText;
static BOOL italicText;
static UIColor *foregroundColor;
static UIColor *backgroundColor;
static NSString *const CQChatInputBarDefaultsChanged = @"CQChatInputBarDefaultsChanged";

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@interface CQChatInputBar (CQChatInputBarPrivate) <UITextViewDelegate, CQTextCompletionViewDelegate>
@property (readonly) BOOL _hasMarkedText;

- (void) _moveCaretToOffset:(NSUInteger) offset;
- (void) _updateTextTraits;
@end

NS_ASSUME_NONNULL_END

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@implementation CQChatInputBar {
@protected
	UIView *_backgroundView;
	CQTextCompletionView *_completionView;
	NSArray <NSString *> *_completions;
	NSRange _completionRange;
	BOOL _completionCapturedKeyboard;
	BOOL _disableCompletionUntilNextWord;
	BOOL _autocapitalizeNextLetter;
	BOOL _textNeedsClearing;
	UITextAutocapitalizationType _defaultAutocapitalizationType;
	UIImageView *_overlayBackgroundView;
	UIImageView *_overlayBackgroundViewPiece;
	UIView *_topLineView;
	NSMutableDictionary *_accessoryImages;
	NSMutableDictionary *_accessibilityLabels;
	CQChatInputBarResponderState _responderState;
}

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

		[self userDefaultsChanged];
	});
}

+ (void) userDefaultsChanged {
	boldText = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQChatStyleBoldText"];
	underlineText = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQChatStyleUnderlineText"];
	italicText = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQChatStyleItalicText"];

	foregroundColor = [UIColor colorFromName:[[NSUserDefaults standardUserDefaults] objectForKey:@"CQChatStyleForegroundTextColor"]];
	backgroundColor = [UIColor colorFromName:[[NSUserDefaults standardUserDefaults] objectForKey:@"CQChatStyleBackgroundTextColor"]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:CQChatInputBarDefaultsChanged object:nil];
}

- (void) _commonInitialization {
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_resetTextAttributes) name:CQChatInputBarDefaultsChanged object:nil];
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

	frame = CGRectMake(6 + (1 / [UIScreen mainScreen].nativeScale), 6.5 + (1 / [UIScreen mainScreen].nativeScale), frame.size.width - 12., frame.size.height - 12.);

	_inputView = [[CQTextView alloc] initWithFrame:frame];
	_inputView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	_inputView.textContainer.heightTracksTextView = YES;
#if !SYSTEM(TV)
	_inputView.dataDetectorTypes = UIDataDetectorTypeNone;
#endif
	_inputView.returnKeyType = UIReturnKeySend;
	_inputView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_inputView.enablesReturnKeyAutomatically = YES;
	_inputView.delegate = self;
	_inputView.backgroundColor = [UIColor clearColor];
	_inputView.font = [UIFont systemFontOfSize:16.];
	_inputView.textColor = [UIColor blackColor];
	_inputView.scrollEnabled = NO;

	_inputView.layer.borderColor = [UIColor colorWithRed:(200. / 255.) green:(200. / 255.) blue:(205. / 255.) alpha:1.].CGColor;
	_inputView.layer.borderWidth = (1 / [UIScreen mainScreen].nativeScale);
	_inputView.layer.backgroundColor = [UIColor colorWithWhite:(250. / 255.) alpha:1.].CGColor;
	_inputView.layer.cornerRadius = 5.;
	[self addSubview:_inputView];

	[self _resetTextAttributes];

	_autocomplete = YES;

#if ENABLE(SECRETS)
	_inputView.autocorrectionType = UITextAutocorrectionTypeDefault;
#else
	_inputView.autocorrectionType = UITextAutocorrectionTypeNo;
	_autocorrect = NO;
#endif

#if !SYSTEM(TV)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideCompletions) name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

	_accessoryButton = [UIButton buttonWithType:UIButtonTypeCustom];

	[_accessoryButton addTarget:self action:@selector(accessoryButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

	[self addSubview:_accessoryButton];

	_accessoryImages = [[NSMutableDictionary alloc] init];
	_accessibilityLabels = [[NSMutableDictionary alloc] init];
}

#pragma mark -

- (instancetype) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (nullable instancetype) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_inputView.delegate = nil;
	_completionView.delegate = nil;
}

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	return [_inputView canBecomeFirstResponder];
}

- (BOOL) becomeFirstResponder {
	return [_inputView becomeFirstResponder];
}

- (BOOL) canResignFirstResponder {
	return [_inputView canResignFirstResponder];
}

- (BOOL) resignFirstResponder {
	return [_inputView resignFirstResponder];
}

- (BOOL) isFirstResponder {
	return [_inputView isFirstResponder];
}

- (BOOL) canPerformAction:(SEL) action withSender:(__nullable id) sender {
	[self hideCompletions];
	return NO;
}

- (void) setAccessibilityLabel:(NSString *) accessibilityLabel forResponderState:(CQChatInputBarResponderState) responderState {
	_accessoryButton.accessibilityLabel = _accessibilityLabels[@(responderState)];
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

- (void) updateTextViewContentSize {
	CGFloat contentWidth = CGRectGetWidth(_inputView.bounds) - (_inputView.contentInset.left + _inputView.contentInset.right) - 8.0;
	CGSize calculatableSize = CGSizeMake(contentWidth, CGFLOAT_MAX);
	const NSStringDrawingOptions options = (NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesDeviceMetrics);
	NSDictionary *attributes = self._textAttributes;

	CGSize textSize = [_inputView.text boundingRectWithSize:calculatableSize options:options attributes:attributes context:nil].size;
	CGFloat lineHeight = ceilf([attributes[NSFontAttributeName] lineHeight]);

	if (lineHeight == 0) {
		lineHeight = CQLineHeight;
	}

	UIEdgeInsets insets = _inputView.contentInset;
	insets.top = 4.0;
	insets.bottom = 0.0;
	_inputView.contentInset = insets;

	CGSize newFrameSize = textSize;
	if (newFrameSize.height > lineHeight * 4) {
		newFrameSize.height = lineHeight * 4;
	} else if (newFrameSize.height < lineHeight * 2) {
		newFrameSize.height = lineHeight * 2;
	} else {
		newFrameSize.height = ceilf(newFrameSize.height);
	}

	newFrameSize.height += CQInputBarVerticalPadding;

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	BOOL shouldSetHeight = YES;
	if (strongDelegate && [strongDelegate respondsToSelector:@selector(chatInputBar:shouldChangeHeightBy:)])
		shouldSetHeight = [strongDelegate chatInputBar:self shouldChangeHeightBy:(self.bounds.size.height - newFrameSize.height)];

	if (shouldSetHeight) {
		self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, newFrameSize.height);

		textSize.height += (insets.top + insets.bottom);
		_inputView.contentSize = textSize;

		_inputView.scrollEnabled = (textSize.height >= CGRectGetHeight(_inputView.frame));

		if (_inputView.scrollEnabled)
			[_inputView scrollRangeToVisible:_inputView.selectedRange];
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
	if (font.pointSize == _inputView.font.pointSize)
		return;

	if (font.pointSize > .0) {
		UIFontDescriptorSymbolicTraits symbolicTraits = font.fontDescriptor.symbolicTraits;
		if (italicText) symbolicTraits |= UIFontDescriptorTraitItalic;
		else if ((symbolicTraits & UIFontDescriptorTraitItalic) == UIFontDescriptorTraitItalic) symbolicTraits ^= UIFontDescriptorTraitItalic;

		if (boldText) symbolicTraits |= UIFontDescriptorTraitBold;
		else if ((symbolicTraits & UIFontDescriptorTraitBold) == UIFontDescriptorTraitBold) symbolicTraits ^= UIFontDescriptorTraitBold;

		UIFontDescriptor *fontDescriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
		_inputView.font = [UIFont fontWithDescriptor:fontDescriptor size:font.pointSize];
	}

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

	NSArray <NSString *> *completions = [strongDelegate chatInputBar:self completionsForWordWithPrefix:text inRange:range];
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
	_completionView.completions = @[];

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

	NSArray <NSString *> *completions = _completions;
	NSString *suffixText = nil;
	BOOL isFirstWord = NO;
	if (_completionRange.location == 0) {
		isFirstWord = YES;

		NSUInteger spaceIndex = [_inputView.text rangeOfString:@" "].length;
		if (spaceIndex == 0) {
			suffixText = [_inputView.text copy];
		} else {
			suffixText = [[_inputView.text substringToIndex:spaceIndex] copy];
		}
	} else {
		suffixText = [[text substringFromIndex:_completionRange.location] copy];
	}

	CGSize textSize = [suffixText sizeWithAttributes:@{ NSFontAttributeName: _inputView.font }];
	CGRect inputFrame = [self convertRect:_inputView.frame toView:self.superview];

retry:
	_completionView.completions = completions;
	[_completionView sizeToFit];

	CGRect frame = _completionView.frame;
	frame.origin = inputFrame.origin;

	CGRect cursorPosition = [_inputView caretRectForPosition:_inputView.selectedTextRange.start];
	cursorPosition = [self convertRect:cursorPosition toView:self.superview];

	frame = _completionView.frame;
	frame.origin = inputFrame.origin;
	frame.origin.y = CGRectGetMinY(cursorPosition) - 31.;
	frame.origin.x = CGRectGetMaxX(cursorPosition) - (5. + textSize.width);

	if ((frame.origin.x + _completionView.bounds.size.width) > CGRectGetMaxX(inputFrame))
		frame.origin.x -= ((frame.origin.x + _completionView.bounds.size.width) - CGRectGetMaxX(inputFrame));

	if (!isFirstWord && frame.origin.x < inputFrame.origin.x) {
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

- (void) showCompletions:(NSArray <NSString *> *) completions forText:(NSString *) text inRange:(NSRange) textRange {
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

- (void) accessoryButtonPressed:(__nullable id) sender {
	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if (strongDelegate && [strongDelegate respondsToSelector:@selector(chatInputBarAccessoryButtonPressed:)])
		[strongDelegate chatInputBarAccessoryButtonPressed:self];
}

#pragma mark -

- (void) keyboardWillShow:(NSNotification *) notification {
	if (![notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue])
		return;

	_responderState = CQChatInputBarResponder;

	[self _updateImagesForResponderState];

	[self setNeedsLayout];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	_responderState = CQChatInputBarNotResponder;

	[self _updateImagesForResponderState];

	[self setNeedsLayout];
}

- (void) scrollViewDidScroll:(UIScrollView *) scrollView {
	scrollView.contentOffset = CGPointMake(0.0, fmaxf(scrollView.contentInset.top, scrollView.contentOffset.y));
}

- (BOOL) textViewShouldBeginEditing:(UITextView *) textView {
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

		if (![strongDelegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)] && ![strongDelegate respondsToSelector:@selector(chatInputBar:completionsForWordWithPrefix:inRange:)])
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
		NSArray <NSString *> *completions = nil;
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

	if (!textView.text.length)
		[self _resetTextAttributes];

	__strong __typeof__((_delegate)) strongDelegate = _delegate;
	if ([strongDelegate respondsToSelector:@selector(chatInputBarTextDidChange:)])
		[strongDelegate chatInputBarTextDidChange:self];
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

	_topLineView.frame = CGRectMake(0., 0., CGRectGetWidth(_backgroundView.frame), (1 / [UIScreen mainScreen].nativeScale));
#define ButtonMargin 6 + (1 / [UIScreen mainScreen].nativeScale)
#define ButtonWidth 18.
	__block CGRect frame = _backgroundView.frame;
	frame.size.width -= (ButtonWidth + floorf(ButtonMargin));
	_overlayBackgroundView.frame = frame;

	frame.origin.x = CGRectGetMaxX(frame);
	frame.size.width = CGRectGetWidth(self.frame) - CGRectGetMinX(frame);
	_overlayBackgroundViewPiece.frame = frame;

	frame = self.bounds;
	frame = CGRectMake(6 + (1 / [UIScreen mainScreen].nativeScale), 6 + (1 / [UIScreen mainScreen].nativeScale), frame.size.width - 12., frame.size.height - 12.);

	frame.size.width = _backgroundView.frame.size.width - (frame.origin.x * 2);
	frame.size.width -= (ButtonWidth + floorf(ButtonMargin));

	frame.size.height = (self.frame.size.height - CQInputBarVerticalPadding);
	frame.origin.y = (self.frame.size.height - frame.size.height) / 2.;
	_inputView.frame = frame;
	_inputView.textContainer.size = CGSizeMake(frame.size.width, 0); // 0 = unlimited space

	frame = _accessoryButton.frame;
	frame.origin.x = CGRectGetMaxX(_inputView.frame) + floorf(ButtonMargin);
	frame.origin.y = (ButtonMargin * 2);
	frame.size.width = ButtonWidth;
	frame.size.height = ButtonWidth;

	_accessoryButton.frame = frame;

#undef ButtonWidth
#undef ButtonMargin
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
#if ENABLE(SECRETS)
//	static Class keyboardClass;
//	if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");
//
//	NSAssert(keyboardClass, @"UIKeyboardImpl class does not exist.");
//
//	__strong id keyboard = [keyboardClass performPrivateSelector:@"activeInstance"];
//	if (!keyboard)
//		return;
//
//	static SEL takeTextInputTraitsFromDelegateSelector;
//	if (!takeTextInputTraitsFromDelegateSelector)
//		takeTextInputTraitsFromDelegateSelector = NSSelectorFromString(@"takeTextInputTraitsFromDelegate");
//
//	static SEL takeTextInputTraitsFromSelector;
//	if (!takeTextInputTraitsFromSelector)
//		takeTextInputTraitsFromSelector = NSSelectorFromString(@"takeTextInputTraitsFrom:");
//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//
//	NSAssert([keyboard respondsToSelector:takeTextInputTraitsFromDelegateSelector] || [keyboard respondsToSelector:takeTextInputTraitsFromSelector], @"UIKeyboardImpl does not respond to takeTextInputTraitsFromDelegate or takeTextInputTraitsFrom:.");
//	if ([keyboard respondsToSelector:takeTextInputTraitsFromDelegateSelector])
//		[keyboard performSelector:takeTextInputTraitsFromDelegateSelector];
//	else if ([keyboard respondsToSelector:takeTextInputTraitsFromSelector])
//		[keyboard performSelector:takeTextInputTraitsFromSelector withObject:_inputView];
//
//#pragma clang diagnostic pop
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
		[self _resetTextAttributes];
	}
}

- (void) _resetTextViewHeight {
	[self updateTextViewContentSize];
}

- (NSDictionary *) _textAttributes {
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	attributes[NSFontAttributeName] = self.font;
	attributes[NSUnderlineStyleAttributeName] = (underlineText ? @(NSUnderlineStyleSingle) : @(NSUnderlineStyleNone));

	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	paragraphStyle.lineSpacing = 1.1;
	paragraphStyle.lineHeightMultiple = 1.1;

	attributes[NSParagraphStyleAttributeName] = [paragraphStyle copy];

	if (foregroundColor) attributes[NSForegroundColorAttributeName] = foregroundColor;
	if (backgroundColor) attributes[NSBackgroundColorAttributeName] = backgroundColor;

	return [attributes copy];
}

- (void) _resetTextAttributes {
	if (_textNeedsClearing) {
		_textNeedsClearing = NO;
		return;
	}

	self.font = self.font; // recalculate bold/italic settings

	NSDictionary *attributes = self._textAttributes;

	NSMutableAttributedString *attributedString = [_inputView.attributedText mutableCopy];
	_textNeedsClearing = NO;
	if (!attributedString.length) {
		_textNeedsClearing = YES;
		attributedString = [[NSMutableAttributedString alloc] initWithString:(_inputView.text.length ? _inputView.text : @" ")];
	}

	[attributedString setAttributes:attributes range:NSMakeRange(0, attributedString.length)];

	_inputView.attributedText = attributedString;

	if (_textNeedsClearing)
		_inputView.text = @"";
}

#pragma mark -

- (void) _updateImagesForResponderState {
	CQChatInputBarResponderState activeResponderState = _responderState;
	if (!_inputView.hasText)
		activeResponderState = CQChatInputBarNotResponder;

	UIImage *defaultImage = _accessoryImages[@(activeResponderState)][@(UIControlStateNormal)];
	if (defaultImage)
		[_accessoryButton setImage:defaultImage forState:UIControlStateNormal];

	UIImage *pressedImage = _accessoryImages[@(activeResponderState)][@(UIControlStateHighlighted)];
	[_accessoryButton setImage:pressedImage forState:UIControlStateHighlighted];

	_accessoryButton.accessibilityLabel = _accessibilityLabels[@(activeResponderState)];
}
@end

NS_ASSUME_NONNULL_END
