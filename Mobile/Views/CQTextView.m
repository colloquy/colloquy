#import "CQTextView.h"

@implementation CQTextView
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	self.layer.masksToBounds = YES;
	self.layer.cornerRadius = 10.;

	_placeholderTextColor = [UIColor lightGrayColor];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewChanged:) name:UITextViewTextDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_placeholder release];

	[_textColor release];
	[_placeholderTextColor release];

	[super dealloc];
}

#pragma mark -

- (UIColor *) textColor {
	return self.isPlaceholderText ? _placeholderTextColor : _textColor;
}

- (void) updateTextColor {
	[super setTextColor:self.textColor];
}

- (void) setTextColor:(UIColor *) color {
	id old = _textColor;
	_textColor = [color retain];
	[old release];

	[self updateTextColor];
}

@synthesize placeholderTextColor = _placeholderTextColor;

- (void) setPlaceholderTextColor:(UIColor *) color {
	id old = _placeholderTextColor;
	_placeholderTextColor = [color retain];
	[old release];

	[self updateTextColor];
}

#pragma mark -

- (void) setText:(NSString *) text {
	NSString *placeholder = self.placeholder;

	if (!text.length && placeholder.length)
		[super setText:placeholder];
	else [super setText:text];

	[self updateTextColor];
}

- (NSString *) text {
	if (self.isPlaceholderText)
		return @"";
	return [super text];
}

@synthesize placeholder = _placeholder;

- (void) setPlaceholder:(NSString *) placeholder {
	id old = _placeholder;
	_placeholder = [placeholder copy];

	if (![super text].length && _placeholder.length)
		self.text = _placeholder;

	[old release];
}

- (BOOL) isPlaceholderText {
	return [[super text] isEqualToString:_placeholder];
}

#pragma mark -

- (BOOL) becomeFirstResponder {
	if (![super becomeFirstResponder])
		return NO;

	if (self.isPlaceholderText)
		[super setText:@""];

	return YES;
}

- (BOOL) canPerformAction:(SEL) action withSender:(id) sender {
	if (self.isPlaceholderText)
		return NO;
	return [super canPerformAction:action withSender:sender];
}

- (void) textViewChanged:(NSNotification *) notification {
	NSString *text = self.text;

	if (text.length) {
		if ([text hasSuffix:_placeholder])
			self.text = [text substringWithRange:NSMakeRange(0, text.length - _placeholder.length)];
	} else {
		self.placeholder = _placeholder;
		self.selectedRange = NSMakeRange(0, 0);
	}

	[self updateTextColor];
}
@end
