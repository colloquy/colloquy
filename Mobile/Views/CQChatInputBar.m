#import "CQChatInputBar.h"

@implementation CQChatInputBar
- (void) _commonInitialization {
	CGRect frame = self.frame;

	_inputField = [[UITextField alloc] initWithFrame:CGRectMake(6., 6., frame.size.width - 12., frame.size.height - 14.)];
	_inputField.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	_inputField.borderStyle = UITextBorderStyleRoundedRect;
	_inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_inputField.returnKeyType = UIReturnKeySend;
	_inputField.delegate = self;

	[self addSubview:_inputField];
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

	// Perform work on a delay so pending auto-corrections can be committed.
	[self performSelector:@selector(_sendText) withObject:nil afterDelay:0.];

	return YES;
}

#pragma mark -

- (void) _sendText {
	// Resign and become first responder to accept any pending auto-correction.
	[_inputField resignFirstResponder];
	[_inputField becomeFirstResponder];

	if ([delegate chatInputBar:self sendText:_inputField.text])
		_inputField.text = @"";	
}
@end
