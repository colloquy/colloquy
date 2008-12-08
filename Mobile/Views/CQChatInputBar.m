#import "CQChatInputBar.h"

struct CQEmojiEmoticon {
	unichar emoji;
	NSString *emoticon;
};

static struct CQEmojiEmoticon emojiEmoticonMap[] = {
	{ 0xe00e, @"(Y)" },
	{ 0xe022, @"<3" },
	{ 0xe023, @"</3" },
	{ 0xe056, @":)" },
	{ 0xe057, @":D" },
	{ 0xe058, @":(" },
	{ 0xe105, @";P" },
	{ 0xe106, @"(<3" },
	{ 0xe11a, @">:)" },
	{ 0xe401, @":'(" },
	{ 0xe404, @":-!" },
	{ 0xe405, @";)" },
	{ 0xe409, @":P" },
	{ 0xe410, @":O" },
	{ 0xe411, @":\"o" },
	{ 0xe412, @":'D" },
	{ 0xe414, @":[" },
	{ 0xe415, @"^-^" },
	{ 0xe417, @":-*" },
	{ 0xe418, @";-*" },
	{ 0xe421, @"(N)" },
};

#pragma mark -

@interface UIKeyboardImpl : UIView
+ (UIKeyboardImpl *) activeInstance;
- (void) takeTextInputTraitsFrom:(id <UITextInputTraits>) object;
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

#pragma mark -

- (void) _sendText {
	// Resign and become first responder to accept any pending auto-correction.
	[_inputField resignFirstResponder];
	[_inputField becomeFirstResponder];

	NSString *text = _inputField.text;

	NSCharacterSet *emojiCharacters = [NSCharacterSet characterSetWithRange:NSMakeRange(0xe001, (0xe53e - 0xe001))];
	NSRange emojiRange = [text rangeOfCharacterFromSet:emojiCharacters];
	if (emojiRange.location != NSNotFound) {
		NSMutableString *mutableText = [text mutableCopy];

		while (emojiRange.location != NSNotFound) {
			unichar currentCharacter = [mutableText characterAtIndex:emojiRange.location];
			for (struct CQEmojiEmoticon *entry = emojiEmoticonMap; entry && entry->emoji; ++entry) {
				if (entry->emoji == currentCharacter) {
					NSString *replacement = nil;
					if (emojiRange.location == 0 && (emojiRange.location + 1) == mutableText.length)
						replacement = [entry->emoticon retain];
					else if (emojiRange.location > 0 && (emojiRange.location + 1) == mutableText.length && [mutableText characterAtIndex:(emojiRange.location - 1)] == ' ')
						replacement = [entry->emoticon retain];
					else if ([mutableText characterAtIndex:(emojiRange.location - 1)] == ' ' && [mutableText characterAtIndex:(emojiRange.location + 1)] == ' ')
						replacement = [entry->emoticon retain];
					else if (emojiRange.location == 0 || [mutableText characterAtIndex:(emojiRange.location - 1)] == ' ')
						replacement = [[NSString alloc] initWithFormat:@"%@ ", entry->emoticon];
					else if ((emojiRange.location + 1) == mutableText.length || [mutableText characterAtIndex:(emojiRange.location + 1)] == ' ')
						replacement = [[NSString alloc] initWithFormat:@" %@", entry->emoticon];
					else replacement = [[NSString alloc] initWithFormat:@" %@ ", entry->emoticon];

					[mutableText replaceCharactersInRange:NSMakeRange(emojiRange.location, 1) withString:replacement];

					[replacement release];
					break;
				}
			}

			emojiRange = [mutableText rangeOfCharacterFromSet:emojiCharacters options:NSLiteralSearch range:NSMakeRange(emojiRange.location + 1, (mutableText.length - emojiRange.location - 1))];
		}

		text = [mutableText autorelease];
	}

	if (![delegate chatInputBar:self sendText:text])
		return;

	if (_inferAutocapitalizationType) {
		NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
		if ([uppercaseSet characterIsMember:[text characterAtIndex:0]])
			_inputField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		else _inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;

		static Class keyboardClass;
		if (!keyboardClass) keyboardClass = NSClassFromString(@"UIKeyboardImpl");

		if ([keyboardClass respondsToSelector:@selector(activeInstance)]) {
			UIKeyboardImpl *keyboard = [keyboardClass activeInstance];
			if ([keyboard respondsToSelector:@selector(takeTextInputTraitsFrom:)])
				[keyboard takeTextInputTraitsFrom:_inputField];
		}
	}

	_inputField.text = @"";
}
@end
