#import "CQChatInputBar.h"

#import "NSStringAdditions.h"

@interface UIKeyboardImpl : UIView
+ (UIKeyboardImpl *) activeInstance;
- (void) takeTextInputTraitsFrom:(id <UITextInputTraits>) object;
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
	_inputField.returnKeyType = UIReturnKeySend;
	_inputField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_inputField.enablesReturnKeyAutomatically = YES;
	_inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
	_inputField.delegate = self;

	[self addSubview:_inputField];

	_inferAutocapitalizationType = YES;
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
	[_inputField release];
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
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	if (![delegate respondsToSelector:@selector(chatInputBar:sendText:)])
		return NO;

	if (!_inputField.text.length)
		return NO;

	// Perform work on a delay so pending auto-corrections can be committed.
	[self performSelector:@selector(_sendText) withObject:nil afterDelay:0.];

	return YES;
}

- (BOOL) textFieldShouldClear:(UITextField *) textField {
	_inputField.autocorrectionType = UITextAutocorrectionTypeDefault;

	[self _updateTextTraits];

	return YES;
}

- (BOOL) textField:(UITextField *) textField shouldChangeCharactersInRange:(NSRange) range replacementString:(NSString *) string {
	if (![delegate respondsToSelector:@selector(chatInputBar:shouldAutocorrectWordWithPrefix:)])
		return YES;

	NSRange wordRange = {0, range.location + string.length};
	NSString *text = [_inputField.text stringByReplacingCharactersInRange:range withString:string];
	
	for (NSInteger i = (range.location + string.length - 1); i >= 0; --i) {
		if ([text characterAtIndex:i] == ' ') {
			wordRange.location = i + 1;
			wordRange.length = ((range.location + string.length) - wordRange.location);
			break;
		}
	}

	NSString *word = [text substringWithRange:wordRange];

	UITextAutocorrectionType newAutocorrectionType = _inputField.autocorrectionType;
	if (![delegate chatInputBar:self shouldAutocorrectWordWithPrefix:word])
		newAutocorrectionType = UITextAutocorrectionTypeNo;
	else newAutocorrectionType = UITextAutocorrectionTypeDefault;

	if (newAutocorrectionType != _inputField.autocorrectionType) {
		_inputField.autocorrectionType = newAutocorrectionType;
		[self _updateTextTraits];
	}

	return YES;
}

#pragma mark -

- (void) _updateTextTraits {
	static Class keyboardClass;
	if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");

	if ([keyboardClass respondsToSelector:@selector(activeInstance)]) {
		UIKeyboardImpl *keyboard = [keyboardClass activeInstance];
		if ([keyboard respondsToSelector:@selector(takeTextInputTraitsFrom:)])
			[keyboard takeTextInputTraitsFrom:_inputField];
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
	_inputField.autocorrectionType = UITextAutocorrectionTypeDefault;

	[self _updateTextTraits];
}
@end
